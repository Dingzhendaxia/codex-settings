% Install in the userpath confirmed by MATLAB. Merge with existing startup.
initializeMathWorksAgenticToolkits;

function initializeMathWorksAgenticToolkits
    try
        % For a custom installation, replace toolkitRoot with the actual root.
        toolkitRoot = fullfile(getenv('APPDATA'), 'MathWorks', ...
            'Agentic Toolkits', 'v1');
        simulinkToolkit = fullfile(toolkitRoot, 'toolkits', ...
            'simulink-agentic-toolkit');
        serverExecutable = fullfile(toolkitRoot, 'bin', ...
            'matlab-mcp-server.exe');
        if ~isfile(fullfile(simulinkToolkit, 'satk_initialize.p')) || ...
                ~isfile(serverExecutable)
            warning('Codex:AgenticToolkitNotFound', ...
                'Agentic toolkit files were not found in %s.', toolkitRoot);
            return
        end
        addpath(simulinkToolkit);
        satk_initialize(MCPServerPath=serverExecutable);
    catch startupError
        warning('Codex:AgenticToolkitStartupFailed', ...
            'Agentic toolkit initialization failed: %s', startupError.message);
    end
end
