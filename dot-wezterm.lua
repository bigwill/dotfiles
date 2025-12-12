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
config.enable_tab_bar = false
config.window_decorations = "RESIZE"   -- or "NONE"
config.font = wezterm.font 'JetBrains Mono'
config.font_size = 14.0
config.harfbuzz_features = { "calt=0", "clig=0", "liga=0" }

------------------------------------------------------------
-- Keybindings
------------------------------------------------------------
local act = wezterm.action

config.keys = {
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
           wezterm cli split-pane --pane-id $WEZTERM_PANE --bottom --percent 50 -- $ssh_cmd
           
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
  { key = '1', mods = 'CMD', action = act.SwitchToWorkspace { name = 'local' } },
  -- For other workspaces, we rely on the order they appear in the switcher or cycle through them
  -- But to explicitly map 2..9 to "next available workspaces", we'd need dynamic logic which is complex in config.
  -- Instead, standard practice is:
  -- CMD+1: local
  -- CMD+2: apollo (if active)
  -- CMD+3...: runpods
  
  -- Let's map CMD+1..9 to "SwitchToWorkspace index=N" logic requires WezTerm nightly or complex callback.
  -- Simpler: Use "ShowLauncher" for list, or "SwitchWorkspaceRelative".
  
  -- Actually, let's just map CMD+1..9 to the built-in workspace switcher slots if possible,
  -- OR map them to specific names if you know them.
  -- Since names are dynamic (runpod-IP), we can't hardcode CMD+3 to a specific IP.

  -- BEST APPROACH: Map CMD+1..9 to "activate workspace by relative index"
  -- (WezTerm doesn't have a direct "activate workspace N" action by default for dynamic lists).
  
  -- Alternative: Use the "ShowLauncher" (CMD+Shift+N) which lists them.
  
  -- However, user asked for "CMD-1..X to access in order".
  -- We can try mapping them to a callback that finds the Nth workspace.
  { key = '1', mods = 'CMD', action = wezterm.action_callback(function(win, pane) win:perform_action(act.SwitchToWorkspace{name='local'}, pane) end) },
  { key = '2', mods = 'CMD', action = wezterm.action_callback(function(win, pane) 
      local workspaces = mux.get_workspace_names()
      table.sort(workspaces) -- Ensure consistent order (alphanumeric usually)
      -- 'local' is usually first or we can filter.
      -- Let's just switch to the 2nd one in the sorted list.
      if workspaces[2] then win:perform_action(act.SwitchToWorkspace{name=workspaces[2]}, pane) end
    end) 
  },
  { key = '3', mods = 'CMD', action = wezterm.action_callback(function(win, pane) 
      local workspaces = mux.get_workspace_names()
      table.sort(workspaces)
      if workspaces[3] then win:perform_action(act.SwitchToWorkspace{name=workspaces[3]}, pane) end
    end) 
  },
  { key = '4', mods = 'CMD', action = wezterm.action_callback(function(win, pane) 
      local workspaces = mux.get_workspace_names()
      table.sort(workspaces)
      if workspaces[4] then win:perform_action(act.SwitchToWorkspace{name=workspaces[4]}, pane) end
    end) 
  },

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

