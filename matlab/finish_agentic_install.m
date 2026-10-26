% Edit agenticRoot for custom installations. Run in the MATLAB desktop.
finishAgenticToolkitInstallation;

function finishAgenticToolkitInstallation
    agenticRoot = fullfile(getenv('APPDATA'), 'MathWorks', ...
        'Agentic Toolkits', 'v1');
    packages = {'matlab-mcp-server.mltbx', 'simulink-agentic-toolkit.mltbx'};
    for packageIndex = 1:numel(packages)
        packageFile = fullfile(agenticRoot, 'mltbx', packages{packageIndex});
        assert(isfile(packageFile), 'Codex:MissingPackage', ...
            'Package not found: %s', packageFile);
        matlab.addons.install(packageFile);
    end
    rehash toolboxcache;
    addpath(fullfile(agenticRoot, 'toolkits', 'simulink-agentic-toolkit'));
    satk_initialize(MCPServerPath=fullfile(agenticRoot, 'bin', ...
        'matlab-mcp-server.exe'));
end
