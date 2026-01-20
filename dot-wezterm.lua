local wezterm = require 'wezterm'
local mux = wezterm.mux

-- Build a config table (newer wezterm gives nicer errors with config_builder)
local config = {}
if wezterm.config_builder then
  config = wezterm.config_builder()
end

------------------------------------------------------------
-- gui-startup: set up the two workspaces + layouts
------------------------------------------------------------
wezterm.on('gui-startup', function(cmd)
  -- Preserve args if wezterm was started as: wezterm start -- <something>
  local args = {}
  if cmd and cmd.args then
    args = cmd.args
  end

  --------------------------------------------------------
  -- Workspace: "local"  (two local panes side-by-side)
  --------------------------------------------------------
  do
    local tab, left_pane, window = mux.spawn_window {
      workspace = 'local',
      cwd = wezterm.home_dir,
      args = args, -- usually just your shell
    }

    window:gui_window():maximize()

    -- Right pane: second local shell
    left_pane:split {
      direction = 'Right',
      size = 0.5,          -- 50% / 50%
      cwd = wezterm.home_dir,
    }
  end

  --------------------------------------------------------
  -- Workspace: "apollo" (remote GPU box)
  --  - Left: ssh apollo
  --  - Top-right: ssh apollo + gpustat
  --  - Bottom-right: ssh apollo
  --------------------------------------------------------
  -- Removed static startup logic for apollo.
  -- See keybinding 'A' to launch it on demand.

  -- Start focused on the "local" workspace
  mux.set_active_workspace 'local'
end)

------------------------------------------------------------
-- Appearance
------------------------------------------------------------
config.enable_tab_bar = true
config.hide_tab_bar_if_only_one_tab = true  -- Show tab bar only when multiple tabs
config.tab_bar_at_bottom = false
config.window_decorations = "RESIZE"   -- or "NONE"
config.font = wezterm.font 'JetBrains Mono'
config.font_size = 14.0
config.harfbuzz_features = { "calt=0", "clig=0", "liga=0" }

------------------------------------------------------------
-- Claude workspace state (stored per workspace via name encoding)
-- Workspace name format: claude-{repo}-{timestamp}
------------------------------------------------------------
local claude_workspace_state = {}

------------------------------------------------------------
-- Keybindings
------------------------------------------------------------
local act = wezterm.action

-- Helper to get sorted workspaces in preferred order:
-- 'local' first, then claude-* workspaces, then runpod-* workspaces, then 'apollo' last
local function get_sorted_workspaces()
  local workspaces = mux.get_workspace_names()
  local local_ws = {}
  local claude_ws = {}
  local runpod_ws = {}
  local apollo_ws = {}
  local other_ws = {}

  for _, name in ipairs(workspaces) do
    if name == 'local' then
      table.insert(local_ws, name)
    elseif name:match('^claude') then
      table.insert(claude_ws, name)
    elseif name:match('^runpod') then
      table.insert(runpod_ws, name)
    elseif name == 'apollo' then
      table.insert(apollo_ws, name)
    else
      table.insert(other_ws, name)
    end
  end

  -- Sort workspaces by name (chronological if using timestamps)
  table.sort(claude_ws)
  table.sort(runpod_ws)
  table.sort(other_ws)

  -- Concatenate in order: local, claude-*, runpod-*, other, apollo
  local result = {}
  for _, ws in ipairs(local_ws) do table.insert(result, ws) end
  for _, ws in ipairs(claude_ws) do table.insert(result, ws) end
  for _, ws in ipairs(runpod_ws) do table.insert(result, ws) end
  for _, ws in ipairs(other_ws) do table.insert(result, ws) end
  for _, ws in ipairs(apollo_ws) do table.insert(result, ws) end
  return result
end

-- Helper to switch to workspace by index (1-based)
local function switch_to_workspace_by_index(index)
  return wezterm.action_callback(function(win, pane)
    local workspaces = get_sorted_workspaces()
    if workspaces[index] then
      win:perform_action(act.SwitchToWorkspace({ name = workspaces[index] }), pane)
    end
  end)
end

config.keys = {
  -- Launch Claude Agents Workspace (CMD+SHIFT+C)
  -- Tab-based design with SSH to apollo, tmux sessions, and git worktrees
  -- Coordinator Tab: status pane (top 25%) + command shell (bottom 75%)
  -- Agent Tabs: full-screen, each in its own worktree
  {
    key = 'C',
    mods = 'CMD|SHIFT',
    action = wezterm.action_callback(function(window, pane)
      -- Setup script that prompts for repo and branch, then configures tabs on apollo
      local setup_script = [[
        set -e  # Exit on error (but we'll handle it)
        
        # Default values
        DEFAULT_REPO="abax-kryptos"
        DEFAULT_BRANCH="rust-ckks-system"
        
        echo "Claude Agents Workspace Setup (apollo)"
        echo "======================================="
        echo ""
        echo "Enter repo name (default: $DEFAULT_REPO):"
        read -r repo_input
        REPO="${repo_input:-$DEFAULT_REPO}"
        
        echo "Enter branch name (default: $DEFAULT_BRANCH):"
        read -r branch_input
        BRANCH="${branch_input:-$DEFAULT_BRANCH}"
        
        TMUX_SESSION="claude-$REPO-coordinator"
        
        echo ""
        echo "Setting up workspace: $REPO ($BRANCH)"
        echo "Connecting to apollo..."
        echo ""
        
        # Write state file for CMD+SHIFT+N to read (local)
        STATE_DIR="$HOME/.claude-workspaces"
        mkdir -p "$STATE_DIR"
        STATE_FILE="$STATE_DIR/$REPO.state"
        echo "REPO=$REPO" > "$STATE_FILE"
        echo "BRANCH=$BRANCH" >> "$STATE_FILE"
        echo "AGENT_COUNT=0" >> "$STATE_FILE"
        
        # Function to reconnect
        connect_to_apollo() {
          ssh apollo -A -t "
            REPO='$REPO'
            BRANCH='$BRANCH'
            WORKSPACE_DIR=\"\$HOME/agent-workspace/\$REPO\"
            MAIN_DIR=\"\$WORKSPACE_DIR/main\"
            TMUX_SESSION='$TMUX_SESSION'
            
            # Ensure workspace exists
            if [ ! -d \"\$MAIN_DIR\" ]; then
              echo ''
              echo 'ERROR: Workspace not initialized on apollo.'
              echo ''
              echo 'Run these commands on apollo first:'
              echo \"  mkdir -p \$WORKSPACE_DIR\"
              echo \"  git clone <repo-url> \$MAIN_DIR\"
              echo \"  cd \$MAIN_DIR && git checkout $BRANCH\"
              echo ''
              exit 1
            fi
            
            cd \"\$MAIN_DIR\"
            git checkout '$BRANCH' 2>/dev/null || true
            
            # Always kill existing coordinator session to ensure proper layout
            tmux kill-session -t \"\$TMUX_SESSION\" 2>/dev/null
            
            echo 'Creating coordinator session with split panes...'
            
            # Create new tmux session - this creates window 0 with pane 0
            tmux new-session -d -s \"\$TMUX_SESSION\" -c \"\$MAIN_DIR\"
            
            # Split the window vertically - bottom pane gets 75%
            # After split: pane 0 = top (25%), pane 1 = bottom (75%)
            tmux split-window -t \"\$TMUX_SESSION\" -v -l 75% -c \"\$MAIN_DIR\"
            
            # Verify split worked
            PANE_COUNT=\$(tmux list-panes -t \"\$TMUX_SESSION\" | wc -l)
            echo \"Panes created: \$PANE_COUNT\"
            
            # Top pane (index 0): status watch
            tmux select-pane -t \"\$TMUX_SESSION:0.0\"
            tmux send-keys -t \"\$TMUX_SESSION:0.0\" \"watch -n1 'echo \\\"=== Claude Agents: \$REPO ===\\\"; echo; echo Sessions:; tmux ls 2>/dev/null | grep claude-\$REPO || echo \\\"  (none)\\\"; echo; echo Worktrees:; git worktree list; echo'\" Enter
            
            # Bottom pane (index 1): shell
            tmux select-pane -t \"\$TMUX_SESSION:0.1\"
            tmux send-keys -t \"\$TMUX_SESSION:0.1\" 'clear && echo \"=== Coordinator Shell ===\" && echo && echo \"git worktree list | git diff main..<branch> | git merge <branch>\" && echo' Enter
            
            # Keep bottom pane selected
            tmux select-pane -t \"\$TMUX_SESSION:0.1\"
            
            # Small delay then attach
            sleep 0.5
            tmux attach -t \"\$TMUX_SESSION\"
          "
        }
        
        # Main loop - reconnect if SSH drops
        while true; do
          echo "Connecting to apollo..."
          if connect_to_apollo; then
            echo ""
            echo "Disconnected from apollo."
          else
            echo ""
            echo "Connection failed or error occurred."
          fi
          echo ""
          echo "Press Enter to reconnect, or Ctrl+C to exit."
          read -r
        done
      ]]
      
      -- Create workspace with repo name in it
      local workspace_name = 'claude-' .. os.time()
      
      -- Spawn Coordinator Tab
      local tab, main_pane, win = mux.spawn_window {
        workspace = workspace_name,
        cwd = wezterm.home_dir,
        args = { 'bash', '-c', setup_script },
      }
      
      -- Set tab title
      tab:set_title('Coordinator')
      
      -- Switch to the new workspace
      mux.set_active_workspace(workspace_name)
    end),
  },

  -- Add Agent Tab to current Claude workspace (CMD+SHIFT+N)
  {
    key = 'N',
    mods = 'CMD|SHIFT',
    action = wezterm.action_callback(function(window, pane)
      local current_workspace = window:active_workspace()
      
      -- Only works in claude-* workspaces
      if not current_workspace:match('^claude') then
        wezterm.log_error('CMD+SHIFT+N only works in claude-* workspaces')
        return
      end
      
      -- Script to add a new agent tab (with name prompt and existing agent selection)
      local add_agent_script = [[
        STATE_DIR="$HOME/.claude-workspaces"
        
        # Try to find the most recent state file
        STATE_FILE=$(ls -t "$STATE_DIR"/*.state 2>/dev/null | head -1)
        
        if [ -z "$STATE_FILE" ] || [ ! -f "$STATE_FILE" ]; then
          echo "Error: No active Claude workspace state found."
          echo "Please start a workspace with CMD+SHIFT+C first."
          echo ""
          echo "Press Enter to close..."
          read -r
          exit 1
        fi
        
        # Load state
        source "$STATE_FILE"
        
        echo "=== Add/Attach Agent for $REPO ==="
        echo ""
        
        # Check for existing agent sessions on apollo
        echo "Checking for existing agent sessions..."
        EXISTING=$(ssh apollo "tmux ls 2>/dev/null | grep 'claude-$REPO-agent' | sed 's/:.*//'" 2>/dev/null)
        
        # Function to set tab title via OSC escape sequence
        set_tab_title() {
          printf '\033]1;%s\007' "$1"
        }
        
        if [ -n "$EXISTING" ]; then
          echo ""
          echo "Existing agent sessions:"
          echo "$EXISTING" | nl
          echo ""
          echo "Enter number to reattach, or press Enter for new agent:"
          read -r choice
          
          if [ -n "$choice" ]; then
            # Reattach to existing
            TMUX_SESSION=$(echo "$EXISTING" | sed -n "${choice}p")
            if [ -n "$TMUX_SESSION" ]; then
              echo "Reattaching to $TMUX_SESSION..."
              
              # Extract agent name from session for tab title
              AGENT_NAME=$(echo "$TMUX_SESSION" | sed "s/claude-$REPO-//")
              set_tab_title "$AGENT_NAME"
              
              while true; do
                ssh apollo -A -t "tmux attach -t '$TMUX_SESSION'"
                echo ""
                echo "Disconnected. Press Enter to reconnect, Ctrl+C to exit."
                read -r
              done
            fi
          fi
        fi
        
        # Create new agent
        echo ""
        echo "What task will this agent work on?"
        echo "(This becomes the agent name, e.g., 'ckks-encoder', 'poly-tests')"
        read -r AGENT_NAME
        
        if [ -z "$AGENT_NAME" ]; then
          # Default to numbered agent
          AGENT_NUM=$((AGENT_COUNT + 1))
          AGENT_NAME="agent$AGENT_NUM"
        else
          # Sanitize name (lowercase, replace spaces with dashes)
          AGENT_NAME=$(echo "$AGENT_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')
        fi
        
        # Update state file with new count
        AGENT_NUM=$((AGENT_COUNT + 1))
        sed -i '' "s/AGENT_COUNT=.*/AGENT_COUNT=$AGENT_NUM/" "$STATE_FILE"
        
        AGENT_BRANCH="$BRANCH-$AGENT_NAME"
        TMUX_SESSION="claude-$REPO-$AGENT_NAME"
        
        # Set tab title to agent name
        set_tab_title "$AGENT_NAME"
        
        echo ""
        echo "Creating agent: $AGENT_NAME"
        echo "Branch: $AGENT_BRANCH"
        echo "Session: $TMUX_SESSION"
        echo ""
        
        # Function to connect
        connect_to_apollo() {
          ssh apollo -A -t "
            REPO='$REPO'
            BRANCH='$BRANCH'
            AGENT_NAME='$AGENT_NAME'
            AGENT_BRANCH='$AGENT_BRANCH'
            TMUX_SESSION='$TMUX_SESSION'
            WORKSPACE_DIR=\"\$HOME/agent-workspace/\$REPO\"
            MAIN_DIR=\"\$WORKSPACE_DIR/main\"
            AGENT_DIR=\"\$WORKSPACE_DIR/\$AGENT_NAME\"
            
            # Check if tmux session exists
            if tmux has-session -t \"\$TMUX_SESSION\" 2>/dev/null; then
              echo 'Reattaching to existing session...'
              sleep 1
              tmux attach -t \"\$TMUX_SESSION\"
            else
              echo 'Creating new agent session...'
              
              # Create worktree if needed
              if [ ! -d \"\$AGENT_DIR\" ]; then
                echo 'Creating worktree...'
                cd \"\$MAIN_DIR\" || { echo 'Error: Main worktree not found'; exit 1; }
                git worktree add \"\$AGENT_DIR\" -b \"\$AGENT_BRANCH\" 2>/dev/null || \
                  git worktree add \"\$AGENT_DIR\" \"\$AGENT_BRANCH\" 2>/dev/null || \
                  { echo 'Failed to create worktree'; exit 1; }
              fi
              
              cd \"\$AGENT_DIR\"
              
              # Create tmux session
              tmux new-session -d -s \"\$TMUX_SESSION\" -c \"\$AGENT_DIR\"
              
              # Show welcome message
              tmux send-keys -t \"\$TMUX_SESSION\" \"clear && echo '=== Agent: \$AGENT_NAME ===' && echo 'Repo: \$REPO' && echo 'Branch: \$AGENT_BRANCH' && echo '' && echo 'Run: claude' && echo ''\" Enter
              
              # Attach
              tmux attach -t \"\$TMUX_SESSION\"
            fi
          "
        }
        
        # Main loop - reconnect if SSH drops
        while true; do
          echo "Connecting to apollo..."
          if connect_to_apollo; then
            echo ""
            echo "Disconnected from apollo."
          else
            echo ""
            echo "Connection failed or error occurred."
          fi
          echo ""
          echo "Press Enter to reconnect, or Ctrl+C to exit."
          read -r
        done
      ]]
      
      -- Spawn new tab in current window (not new window!)
      local mux_window = window:mux_window()
      local new_tab, new_pane = mux_window:spawn_tab {
        cwd = wezterm.home_dir,
        args = { 'bash', '-c', add_agent_script },
      }
      -- Tab title set dynamically by the bash script via OSC escape
    end),
  },

  -- Wrap up Agent: merge and cleanup (CMD+SHIFT+W)
  {
    key = 'W',
    mods = 'CMD|SHIFT',
    action = wezterm.action_callback(function(window, pane)
      local current_workspace = window:active_workspace()
      
      -- Only works in claude-* workspaces
      if not current_workspace:match('^claude') then
        wezterm.log_error('CMD+SHIFT+W only works in claude-* workspaces')
        return
      end
      
      -- Script to wrap up an agent
      local wrapup_script = [[
        STATE_DIR="$HOME/.claude-workspaces"
        STATE_FILE=$(ls -t "$STATE_DIR"/*.state 2>/dev/null | head -1)
        
        if [ -z "$STATE_FILE" ] || [ ! -f "$STATE_FILE" ]; then
          echo "Error: No active Claude workspace state found."
          read -p "Press Enter to close..."
          exit 1
        fi
        
        source "$STATE_FILE"
        
        echo "=== Wrap Up Agent for $REPO ==="
        echo ""
        
        # Get list of agent sessions
        AGENTS=$(ssh apollo "tmux ls 2>/dev/null | grep 'claude-$REPO-' | grep -v coordinator | sed 's/:.*//'" 2>/dev/null)
        
        if [ -z "$AGENTS" ]; then
          echo "No agent sessions found."
          read -p "Press Enter to close..."
          exit 0
        fi
        
        echo "Agent sessions:"
        echo "$AGENTS" | nl
        echo ""
        echo "Enter number of agent to wrap up (merge & cleanup):"
        read -r choice
        
        if [ -z "$choice" ]; then
          echo "Cancelled."
          read -p "Press Enter to close..."
          exit 0
        fi
        
        TMUX_SESSION=$(echo "$AGENTS" | sed -n "${choice}p")
        if [ -z "$TMUX_SESSION" ]; then
          echo "Invalid selection."
          read -p "Press Enter to close..."
          exit 1
        fi
        
        AGENT_NAME=$(echo "$TMUX_SESSION" | sed "s/claude-$REPO-//")
        AGENT_BRANCH="$BRANCH-$AGENT_NAME"
        
        echo ""
        echo "Wrapping up: $AGENT_NAME"
        echo "Branch: $AGENT_BRANCH"
        echo ""
        echo "This will:"
        echo "  1. Show uncommitted changes (if any)"
        echo "  2. Merge $AGENT_BRANCH into $BRANCH"
        echo "  3. Delete the worktree"
        echo "  4. Kill the tmux session"
        echo ""
        echo "Continue? (y/n)"
        read -r confirm
        
        if [ "$confirm" != "y" ]; then
          echo "Cancelled."
          read -p "Press Enter to close..."
          exit 0
        fi
        
        echo ""
        echo "Connecting to apollo..."
        
        ssh apollo -A -t "
          REPO='$REPO'
          BRANCH='$BRANCH'
          AGENT_NAME='$AGENT_NAME'
          AGENT_BRANCH='$AGENT_BRANCH'
          TMUX_SESSION='$TMUX_SESSION'
          WORKSPACE_DIR=\"\$HOME/agent-workspace/\$REPO\"
          MAIN_DIR=\"\$WORKSPACE_DIR/main\"
          AGENT_DIR=\"\$WORKSPACE_DIR/\$AGENT_NAME\"
          
          echo ''
          echo '=== Checking agent status ==='
          cd \"\$AGENT_DIR\" 2>/dev/null || { echo 'Agent worktree not found'; exit 1; }
          
          # Check for uncommitted changes
          if [ -n \"\$(git status --porcelain)\" ]; then
            echo ''
            echo 'WARNING: Uncommitted changes in agent worktree:'
            git status --short
            echo ''
            echo 'Please commit or discard changes first.'
            echo 'Run this in the agent session, then try again.'
            read -p 'Press Enter to exit...'
            exit 1
          fi
          
          # Check commits ahead of main branch
          COMMITS_AHEAD=\$(git rev-list --count \$BRANCH..\$AGENT_BRANCH 2>/dev/null || echo '0')
          echo \"Commits to merge: \$COMMITS_AHEAD\"
          
          if [ \"\$COMMITS_AHEAD\" = '0' ]; then
            echo 'No commits to merge.'
          else
            echo ''
            echo 'Commits:'
            git log --oneline \$BRANCH..\$AGENT_BRANCH
          fi
          
          echo ''
          echo '=== Merging into $BRANCH ==='
          cd \"\$MAIN_DIR\"
          git checkout '$BRANCH'
          
          if [ \"\$COMMITS_AHEAD\" != '0' ]; then
            git merge \$AGENT_BRANCH --no-edit
            if [ \$? -ne 0 ]; then
              echo 'Merge failed! Resolve conflicts manually.'
              read -p 'Press Enter to exit...'
              exit 1
            fi
            echo 'Merge successful!'
          fi
          
          echo ''
          echo '=== Cleaning up ==='
          
          # Remove worktree
          echo 'Removing worktree...'
          git worktree remove \"\$AGENT_DIR\" --force 2>/dev/null || rm -rf \"\$AGENT_DIR\"
          
          # Delete branch
          echo 'Deleting branch...'
          git branch -d \"\$AGENT_BRANCH\" 2>/dev/null || git branch -D \"\$AGENT_BRANCH\" 2>/dev/null
          
          # Kill tmux session
          echo 'Killing tmux session...'
          tmux kill-session -t \"\$TMUX_SESSION\" 2>/dev/null
          
          echo ''
          echo '=== Done! ==='
          echo \"Agent '\$AGENT_NAME' has been merged and cleaned up.\"
          echo ''
          read -p 'Press Enter to close this tab...'
        "
      ]]
      
      -- Spawn new tab for wrapup
      local mux_window = window:mux_window()
      local new_tab, new_pane = mux_window:spawn_tab {
        cwd = wezterm.home_dir,
        args = { 'bash', '-c', wrapup_script },
      }
    end),
  },

  -- Launch RunPod Workspace (CMD+SHIFT+P)
  {
    key = 'P',
    mods = 'CMD|SHIFT',
    action = wezterm.action_callback(function(window, pane)
      -- 1. Create the workspace with the Local GPU Dev on the LEFT
      local workspace_name = 'runpod-setup-' .. os.time() -- unique temp name until we know the IP?
                                                         -- Or just keep it generic?
                                                         -- Let's use a generic setup name, or just "runpod"
      
      local local_gpu_dev_args = { 'ssh', '-p', '22128', 'willstockwell@localhost', '-A' }
      local tab, left_pane, window = mux.spawn_window {
        workspace = workspace_name,
        cwd = wezterm.home_dir,
        args = local_gpu_dev_args,
      }

      -- 2. Create the RIGHT pane which runs a script to ask for IP:PORT
      --    and then uses wezterm cli to split itself.
      
      local setup_script = [[
        echo "Enter RunPod Address (IP:PORT):"
        read -r input
        if [ -n "$input" ]; then
           # Clean input
           input=$(echo "$input" | xargs)
           ip=$(echo "$input" | cut -d: -f1)
           port=$(echo "$input" | cut -d: -f2)
           
           if [ -z "$ip" ] || [ -z "$port" ]; then
               echo "Invalid format. Expected IP:PORT"
               sleep 3
               exit 1
           fi
           
           # Construct SSH command
           # Note: We use 'root' as default user for RunPod based on previous context
           ssh_cmd="ssh -A -p $port root@$ip"
           
           echo "Connecting to $ip..."
           
           # Rename workspace (optional, might be tricky from inside pane, skip for now)
           
           # 1. Split current pane (Right) vertically to create Bottom-Right (Shell)
           # We use wezterm cli to split the pane we are running in ($WEZTERM_PANE)
           # Ensure wezterm is in path; on macOS it might not be in default PATH for non-login shells?
           # Try full path if just 'wezterm' fails, usually /Applications/WezTerm.app/Contents/MacOS/wezterm
           
           WEZTERM_BIN="wezterm"
           if ! command -v wezterm &> /dev/null; then
               if [ -f "$HOME/Applications/WezTerm.app/Contents/MacOS/wezterm" ]; then
                   WEZTERM_BIN="$HOME/Applications/WezTerm.app/Contents/MacOS/wezterm"
               else
                   echo "Error: wezterm CLI not found."
                   sleep 5
                   exit 1
               fi
           fi
           
           $WEZTERM_BIN cli split-pane --pane-id $WEZTERM_PANE --bottom --percent 50 -- $ssh_cmd
           
           # 2. Replace current shell (Top-Right) with gpustat via SSH
           remote_cmd="if ! command -v gpustat &> /dev/null; then pip install gpustat; fi; watch -n0.2 gpustat --color"
           exec $ssh_cmd -t "$remote_cmd"
        fi
      ]]

      local right_pane = left_pane:split {
        direction = 'Right',
        size = 0.5,
        args = { 'bash', '-c', setup_script },
      }

      -- Switch to the new workspace
      mux.set_active_workspace(workspace_name)
    end),
  },

  -- Launch Apollo Workspace (CMD+SHIFT+A)
  {
    key = 'A',
    mods = 'CMD|SHIFT',
    action = wezterm.action_callback(function(window, pane)
      local workspace_name = 'apollo'
      local ssh_args = { 'ssh', 'apollo', '-A' }

      -- Check if workspace already exists
      -- (Note: minimal API doesn't easily list workspaces, so we just spawn.
      --  If it exists, you'd usually switch to it, but spawn_window creates a NEW one or adds to it.
      --  For simplicity, we'll just create a new window in that workspace.)
      
      -- Big left pane
      local tab, main_pane, window = mux.spawn_window {
        workspace = workspace_name,
        cwd = wezterm.home_dir,
        args = ssh_args,
      }
      
      -- Top-right pane
      local right = main_pane:split {
        direction = 'Right',
        size = 0.33,
        args = ssh_args,
      }
      
      -- Bottom-right pane
      local bottom_right = right:split {
        direction = 'Bottom',
        size = 0.5,
        args = ssh_args,
      }
      
      -- Start GPU stats
      right:send_text('watch -n0.2 gpustat --color\n')
      
      -- Optional: cd into project
      main_pane:send_text('cd ~/git/blackwell\n')
      bottom_right:send_text('cd ~/git/blackwell\n')
      
      -- Clear screen
      main_pane:send_text('clear\n')
      bottom_right:send_text('clear\n')

      -- Switch to it
      mux.set_active_workspace(workspace_name)
    end),
  },

  -- Workspace switching (CMD+1..9)
  -- Order: 'local' first, then runpod-* workspaces, then 'apollo' last
  { key = '1', mods = 'CMD', action = switch_to_workspace_by_index(1) },
  { key = '2', mods = 'CMD', action = switch_to_workspace_by_index(2) },
  { key = '3', mods = 'CMD', action = switch_to_workspace_by_index(3) },
  { key = '4', mods = 'CMD', action = switch_to_workspace_by_index(4) },
  { key = '5', mods = 'CMD', action = switch_to_workspace_by_index(5) },
  { key = '6', mods = 'CMD', action = switch_to_workspace_by_index(6) },
  { key = '7', mods = 'CMD', action = switch_to_workspace_by_index(7) },
  { key = '8', mods = 'CMD', action = switch_to_workspace_by_index(8) },
  { key = '9', mods = 'CMD', action = switch_to_workspace_by_index(9) },

  -- Pane switching (ALT+1..9)
  { key = '1', mods = 'ALT', action = act.ActivatePaneByIndex(0) },
  { key = '2', mods = 'ALT', action = act.ActivatePaneByIndex(1) },
  { key = '3', mods = 'ALT', action = act.ActivatePaneByIndex(2) },
  { key = '4', mods = 'ALT', action = act.ActivatePaneByIndex(3) },
  { key = '5', mods = 'ALT', action = act.ActivatePaneByIndex(4) },
  { key = '6', mods = 'ALT', action = act.ActivatePaneByIndex(5) },
  { key = '7', mods = 'ALT', action = act.ActivatePaneByIndex(6) },
  { key = '8', mods = 'ALT', action = act.ActivatePaneByIndex(7) },
  { key = '9', mods = 'ALT', action = act.ActivatePaneByIndex(8) },
  { key = '0', mods = 'ALT', action = act.ActivatePaneByIndex(9) },

  -- Pane management (similar to iTerm splits)
  { key = 'd', mods = 'CMD',
    action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = 'd', mods = 'CMD|SHIFT',
    action = act.SplitVertical { domain = 'CurrentPaneDomain' } },

  -- Move between panes with ⌘ + h/j/k/l
  { key = 'h', mods = 'CMD', action = act.ActivatePaneDirection 'Left'  },
  { key = 'l', mods = 'CMD', action = act.ActivatePaneDirection 'Right' },
  { key = 'k', mods = 'CMD', action = act.ActivatePaneDirection 'Up'    },
  { key = 'j', mods = 'CMD', action = act.ActivatePaneDirection 'Down'  },
}

return config

