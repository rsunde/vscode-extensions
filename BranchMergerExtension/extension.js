const vscode = require('vscode');
const cp = require('child_process');

const OUTPUT_CHANNEL_NAME = 'Branch Merger Extension';

function getWorkspaceFolders() {
    return vscode.workspace.workspaceFolders || [];
}

function getActiveWorkspaceFolder() {
    const editor = vscode.window.activeTextEditor;
    if (!editor || !editor.document) return null;
    const uri = editor.document.uri;
    if (!uri) return null;
    return vscode.workspace.getWorkspaceFolder(uri) || null;
}

async function pickWorkspaceFolderForGitOperation({ requireGitRepo }) {
    const folders = getWorkspaceFolders();
    if (folders.length === 0) return null;

    const active = getActiveWorkspaceFolder();
    if (active) {
        if (!requireGitRepo) return active;
        const runGit = createGitRunner(active.uri.fsPath);
        if (await safeIsGitRepo(runGit)) return active;
    }

    if (folders.length === 1) {
        if (!requireGitRepo) return folders[0];
        const runGit = createGitRunner(folders[0].uri.fsPath);
        return (await safeIsGitRepo(runGit)) ? folders[0] : null;
    }

    const items = [];
    for (const folder of folders) {
        if (!requireGitRepo) {
            items.push({
                label: folder.name,
                description: folder.uri.fsPath,
                folder
            });
            continue;
        }

        const runGit = createGitRunner(folder.uri.fsPath);
        const isRepo = await safeIsGitRepo(runGit);
        if (isRepo) {
            items.push({
                label: folder.name,
                description: folder.uri.fsPath,
                folder
            });
        }
    }

    if (items.length === 0) return null;

    const picked = await vscode.window.showQuickPick(items, {
        placeHolder: 'Select which workspace folder/repo to use'
    });

    return picked ? picked.folder : null;
}

function createGitRunner(cwd) {
    return (cmd) => new Promise((resolve, reject) => {
        cp.exec(cmd, { cwd }, (err, stdout, stderr) => {
            if (err) {
                reject(stderr || err.message);
            } else {
                resolve(stdout ? stdout.trim() : '');
            }
        });
    });
}

function normalizeBranchSetting(value) {
    if (value === null || value === undefined) return 'auto';
    const s = String(value).trim();
    return s.length === 0 ? 'auto' : s;
}

async function listLocalBranches(runGit) {
    const branchesOutput = await runGit('git branch --format="%(refname:short)"');
    return branchesOutput.split('\n').map(b => b.trim()).filter(Boolean);
}

async function tryDetectDefaultBranchFromRemoteHead(runGit, remoteName) {
    // Example output: refs/remotes/origin/main
    const ref = await runGit(`git symbolic-ref --quiet refs/remotes/${remoteName}/HEAD`);
    const match = /^refs\/remotes\/.+\/(.+)$/.exec(ref);
    return match ? match[1] : null;
}

async function detectDefaultBranch(runGit, remoteName) {
    // 1) Best: origin/HEAD points to origin/main (or similar)
    try {
        const fromRemoteHead = await tryDetectDefaultBranchFromRemoteHead(runGit, remoteName);
        if (fromRemoteHead) return fromRemoteHead;
    } catch {
        // ignore
    }

    // 2) Heuristic: prefer main/master if present locally
    try {
        const branches = await listLocalBranches(runGit);
        if (branches.includes('main')) return 'main';
        if (branches.includes('master')) return 'master';
        if (branches.includes('develop')) return 'develop';
        if (branches.includes('dev')) return 'dev';
    } catch {
        // ignore
    }

    // 3) Last fallback: try init.defaultBranch, then main/master
    try {
        const initDefault = await runGit('git config --get init.defaultBranch');
        const candidate = (initDefault || '').trim();
        if (candidate) return candidate;
    } catch {
        // ignore
    }

    return null;
}

async function resolveDefaultSourceRef(runGit, config, context, cwd) {
    const remoteName = config.get('remoteName', 'origin');
    const rememberDetectedDefaultBranch = config.get('rememberDetectedDefaultBranch', true);

    const configured = normalizeBranchSetting(config.get('defaultSourceBranch', 'auto'));
    let defaultSourceBranch = configured;

    const cacheKey = cwd ? `defaultBranch:${cwd.toLowerCase()}` : null;

    if (configured === 'auto') {
        const cached = cacheKey ? context.workspaceState.get(cacheKey) : null;
        if (cached && typeof cached === 'string' && cached.trim()) {
            defaultSourceBranch = cached.trim();
        } else {
            const detected = await detectDefaultBranch(runGit, remoteName);
            if (detected) {
                defaultSourceBranch = detected;
                if (rememberDetectedDefaultBranch && cacheKey) {
                    await context.workspaceState.update(cacheKey, detected);
                }
            } else {
                // Prompt only when auto detection fails
                let branches = [];
                try {
                    branches = await listLocalBranches(runGit);
                } catch {
                    branches = [];
                }

                const quickPickChoices = Array.from(new Set([
                    'main',
                    'master',
                    'develop',
                    ...branches
                ])).filter(Boolean);

                const picked = await vscode.window.showQuickPick(quickPickChoices, {
                    placeHolder: 'Select the repo default branch (used as merge source)'
                });

                if (!picked) {
                    throw new Error('Default branch not selected. Set branchMergerExtension.defaultSourceBranch or pick one when prompted.');
                }

                defaultSourceBranch = picked;
                if (rememberDetectedDefaultBranch && cacheKey) {
                    await context.workspaceState.update(cacheKey, picked);
                }
            }
        }
    }

    const preferRemoteTracking = config.get('preferRemoteTracking', true);

    if (preferRemoteTracking) {
        const remoteRef = `${remoteName}/${defaultSourceBranch}`;
        try {
            await runGit(`git rev-parse --verify ${remoteRef}`);
            return { ref: remoteRef, branch: defaultSourceBranch };
        } catch {
            // fall back to local branch
        }
    }

    return { ref: defaultSourceBranch, branch: defaultSourceBranch };
}

async function safeIsGitRepo(runGit) {
    try {
        await runGit('git rev-parse --git-dir');
        return true;
    } catch {
        return false;
    }
}

function activate(context) {
    const outputChannel = vscode.window.createOutputChannel(OUTPUT_CHANNEL_NAME);
    context.subscriptions.push(outputChannel);

    /** @type {Map<string, { sourceRef: string|null, sourceHash: string|null }>} */
    const lastSeenByRepo = new Map();

    let pollTimer = null;
    let pollInFlight = false;

    const startOrRestartPolling = async () => {
        if (pollTimer) {
            clearInterval(pollTimer);
            pollTimer = null;
        }

        const config = vscode.workspace.getConfiguration('branchMergerExtension');
        const pollForUpdates = config.get('pollForUpdates', false);
        if (!pollForUpdates) {
            return;
        }

        const intervalMinutes = Math.max(1, Number(config.get('pollIntervalMinutes', 5)) || 5);
        pollTimer = setInterval(() => {
            void checkDefaultUpdatesForAllRepos({ showNoUpdatesMessage: false });
        }, intervalMinutes * 60 * 1000);

        // Also do one check shortly after activation.
        setTimeout(() => {
            void checkDefaultUpdatesForAllRepos({ showNoUpdatesMessage: false });
        }, 2000);
    };

    const checkDefaultUpdatesForRepo = async ({ showNoUpdatesMessage, workspaceFolder }) => {
        const cwd = workspaceFolder.uri.fsPath;
        const runGit = createGitRunner(cwd);
        const isRepo = await safeIsGitRepo(runGit);
        if (!isRepo) {
            if (showNoUpdatesMessage) vscode.window.showErrorMessage(`'${workspaceFolder.name}' is not a git repository.`);
            return;
        }

        try {
            const config = vscode.workspace.getConfiguration('branchMergerExtension');
            const autoFetchBeforePoll = config.get('autoFetchBeforePoll', true);
            const notifyOnUpdates = config.get('notifyOnUpdates', true);

            const currentBranch = await runGit('git rev-parse --abbrev-ref HEAD');
            const { ref: sourceRef, branch: defaultSourceBranch } = await resolveDefaultSourceRef(runGit, config, context, cwd);

            if (autoFetchBeforePoll) {
                try {
                    await runGit('git fetch --prune');
                } catch (fetchErr) {
                    // Fetch can fail in some setups (auth, offline). Only surface if user explicitly invoked.
                    if (showNoUpdatesMessage) {
                        vscode.window.showWarningMessage(`Fetch failed: ${fetchErr}`);
                    }
                }
            }

            let sourceHash;
            try {
                sourceHash = await runGit(`git rev-parse ${sourceRef}`);
            } catch (err) {
                if (showNoUpdatesMessage) vscode.window.showErrorMessage(`Failed to resolve ${sourceRef}: ${err}`);
                return;
            }

            const repoKey = cwd.toLowerCase();
            const lastSeen = lastSeenByRepo.get(repoKey) || { sourceRef: null, sourceHash: null };

            // Initialize last seen state.
            if (!lastSeen.sourceRef || lastSeen.sourceRef !== sourceRef) {
                lastSeenByRepo.set(repoKey, { sourceRef, sourceHash });
                if (showNoUpdatesMessage) {
                    vscode.window.showInformationMessage(`[${workspaceFolder.name}] Tracking ${sourceRef} for updates.`);
                }
                return;
            }

            if (lastSeen.sourceHash === sourceHash) {
                if (showNoUpdatesMessage) {
                    vscode.window.showInformationMessage(`[${workspaceFolder.name}] No new commits detected on ${sourceRef}.`);
                }
                return;
            }

            // Update seen hash and notify.
            lastSeenByRepo.set(repoKey, { sourceRef, sourceHash });

            // If you're currently on the source branch itself, don't suggest merge.
            const isOnSourceBranch = currentBranch === defaultSourceBranch || currentBranch === sourceRef;

            if (!notifyOnUpdates) {
                return;
            }

            const message = isOnSourceBranch
                ? `[${workspaceFolder.name}] New commits detected on ${sourceRef}.`
                : `[${workspaceFolder.name}] New commits detected on ${sourceRef}. Merge into ${currentBranch}?`;

            const actions = isOnSourceBranch
                ? ['Show commits']
                : ['Merge', 'Show commits'];

            const picked = await vscode.window.showInformationMessage(message, ...actions);
            if (!picked) return;

            if (picked === 'Show commits') {
                outputChannel.clear();
                outputChannel.appendLine(`[${new Date().toISOString()}] [${workspaceFolder.name}] Incoming commits from ${sourceRef} into ${currentBranch}`);
                try {
                    const log = await runGit(`git log --oneline --decorate --max-count=25 ${currentBranch}..${sourceRef}`);
                    outputChannel.appendLine(log || '(No commits listed)');
                } catch (err) {
                    outputChannel.appendLine(`Failed to get log: ${err}`);
                }
                outputChannel.show(true);
                return;
            }

            if (picked === 'Merge') {
                await vscode.window.withProgress({
                    location: vscode.ProgressLocation.Notification,
                    title: `Merging ${sourceRef} into ${currentBranch}...`,
                    cancellable: false
                }, async () => {
                    let stashed = false;
                    try {
                        const status = await runGit('git status --porcelain');
                        if (status.trim()) {
                            await runGit('git stash -u');
                            stashed = true;
                        }

                        // Merge the resolved ref directly (often origin/master), without checkout.
                        await runGit(`git merge ${sourceRef}`);

                        if (stashed) {
                            try {
                                await runGit('git stash pop');
                            } catch (stashErr) {
                                vscode.window.showWarningMessage(`Merge successful, but failed to restore stash: ${stashErr}`);
                                return;
                            }
                        }

                        vscode.window.showInformationMessage(`[${workspaceFolder.name}] Successfully merged ${sourceRef} into ${currentBranch}.`);
                    } catch (err) {
                        let errorMessage = `Merge failed: ${err}`;
                        if (stashed) {
                            errorMessage += ' (Your changes were stashed)';
                        }
                        vscode.window.showErrorMessage(`[${workspaceFolder.name}] ${errorMessage}`);
                    }
                });
            }
        } catch (err) {
            if (showNoUpdatesMessage) {
                vscode.window.showErrorMessage(`[${workspaceFolder.name}] Git error: ${err}`);
            }
        }
    };

    const checkDefaultUpdatesForAllRepos = async ({ showNoUpdatesMessage }) => {
        if (pollInFlight) {
            return;
        }

        const folders = getWorkspaceFolders();
        if (folders.length === 0) {
            if (showNoUpdatesMessage) vscode.window.showErrorMessage('No workspace folder open');
            return;
        }

        pollInFlight = true;
        try {
            for (const folder of folders) {
                await checkDefaultUpdatesForRepo({ showNoUpdatesMessage, workspaceFolder: folder });
            }
        } finally {
            pollInFlight = false;
        }
    };

    let disposable = vscode.commands.registerCommand('branch-merger-extension.mergeBranch', async function () {
        const workspaceFolder = await pickWorkspaceFolderForGitOperation({ requireGitRepo: true });
        if (!workspaceFolder) {
            vscode.window.showErrorMessage('No git repository found in the current workspace.');
            return;
        }

        const cwd = workspaceFolder.uri.fsPath;
        const runGit = createGitRunner(cwd);

        try {
            // Get current branch
            const currentBranch = await runGit('git rev-parse --abbrev-ref HEAD');

            // Get all local branches
            const allBranches = await listLocalBranches(runGit);

            // Filter out current branch
            const otherBranches = allBranches.filter(b => b !== currentBranch);

            if (otherBranches.length === 0) {
                vscode.window.showInformationMessage('No other branches to merge from.');
                return;
            }

            // Get configuration (and resolve default branch if set to auto)
            const config = vscode.workspace.getConfiguration('branchMergerExtension');
            const { branch: defaultSourceBranch } = await resolveDefaultSourceRef(runGit, config, context, cwd);

            // Sort branches: default first, then others alphabetically
            const sortedBranches = otherBranches.sort((a, b) => {
                if (a === defaultSourceBranch) return -1;
                if (b === defaultSourceBranch) return 1;
                return a.localeCompare(b);
            });

            // Create QuickPick items
            const items = sortedBranches.map(branch => {
                const isDefault = branch === defaultSourceBranch;
                return {
                    label: branch,
                    description: isDefault ? '(Default)' : '',
                    detail: isDefault ? `Merge from ${branch} into ${currentBranch}` : undefined
                };
            });

            // Show QuickPick
            const selection = await vscode.window.showQuickPick(items, {
                placeHolder: `Select branch to merge into ${currentBranch}`,
                matchOnDescription: true,
                matchOnDetail: true
            });

            if (!selection) return;

            const branchToMerge = selection.label;

            // Perform merge
            await vscode.window.withProgress({
                location: vscode.ProgressLocation.Notification,
                title: `Merging ${branchToMerge} into ${currentBranch}...`,
                cancellable: false
            }, async () => {
                let stashed = false;
                try {
                    // Check for changes
                    const status = await runGit('git status --porcelain');
                    if (status.trim()) {
                        await runGit('git stash -u');
                        stashed = true;
                    }

                    // Checkout source branch and pull
                    await runGit(`git checkout ${branchToMerge}`);
                    await runGit('git pull');

                    // Checkout target branch
                    await runGit(`git checkout ${currentBranch}`);

                    // Merge
                    await runGit(`git merge ${branchToMerge}`);

                    // Restore stash if needed
                    if (stashed) {
                        try {
                            await runGit('git stash pop');
                        } catch (stashErr) {
                            vscode.window.showWarningMessage(`Merge successful, but failed to restore stash: ${stashErr}`);
                            return;
                        }
                    }

                    vscode.window.showInformationMessage(`[${workspaceFolder.name}] Successfully merged ${branchToMerge} into ${currentBranch}.`);
                } catch (err) {
                    let message = `Merge failed: ${err}`;
                    if (stashed) {
                        message += ' (Your changes were stashed)';
                    }
                    vscode.window.showErrorMessage(`[${workspaceFolder.name}] ${message}`);
                }
            });

        } catch (err) {
            vscode.window.showErrorMessage(`Git error: ${err}`);
        }
    });

    context.subscriptions.push(disposable);

    context.subscriptions.push(vscode.commands.registerCommand('branch-merger-extension.checkDefaultUpdates', async function () {
        const workspaceFolder = await pickWorkspaceFolderForGitOperation({ requireGitRepo: true });
        if (!workspaceFolder) {
            vscode.window.showErrorMessage('No git repository found in the current workspace.');
            return;
        }
        await checkDefaultUpdatesForRepo({ showNoUpdatesMessage: true, workspaceFolder });
    }));

    context.subscriptions.push(vscode.workspace.onDidChangeConfiguration((e) => {
        if (e.affectsConfiguration('branchMergerExtension')) {
            void startOrRestartPolling();
        }
    }));

    void startOrRestartPolling();
}

function deactivate() { }

module.exports = {
    activate,
    deactivate
}
