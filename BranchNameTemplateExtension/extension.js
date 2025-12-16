const vscode = require('vscode');
const cp = require('child_process');

function activate(context) {
    let disposable = vscode.commands.registerCommand('branch-name-template.createBranch', async function () {
        const workspaceFolders = vscode.workspace.workspaceFolders;
        if (!workspaceFolders) {
            vscode.window.showErrorMessage('No workspace folder open');
            return;
        }
        const cwd = workspaceFolders[0].uri.fsPath;

        const config = vscode.workspace.getConfiguration('branchNameTemplate');
        const shouldCheckout = config.get('checkout', true);
        const team = config.get('team', 'MyTeam');
        const autoDetectUsername = config.get('autoDetectUsername', true);
        const manualUsername = config.get('username', '');

        // Helper to run git commands
        const runGit = (cmd) => new Promise((resolve) => {
            cp.exec(cmd, { cwd }, (err, stdout) => resolve(stdout ? stdout.trim() : ''));
        });

        // Resolve variables
        let username = manualUsername;

        if (autoDetectUsername || !username) {
            let detected = await runGit('git config user.name');
            if (!detected) detected = process.env.USERNAME || process.env.USER || 'user';
            username = detected.replace(/\s+/g, '').toLowerCase(); // Sanitize: remove spaces, lowercase
        }

        const baseBranch = await runGit('git rev-parse --abbrev-ref HEAD') || 'master';

        let prefix = config.get('prefix', '${team}/${baseBranch}/${username}/');
        prefix = prefix.replace(/\$\{team\}/g, team)
            .replace(/\$\{baseBranch\}/g, baseBranch)
            .replace(/\$\{username\}/g, username);

        // Prompt for branch name with the prefix pre-filled
        const branchName = await vscode.window.showInputBox({
            prompt: 'Enter new branch name',
            value: prefix,
            valueSelection: [prefix.length, prefix.length], // Cursor at the end
            placeHolder: 'Team/Base/User/Description'
        });

        if (!branchName) return;

        const gitCommand = shouldCheckout ? `git checkout -b "${branchName}"` : `git branch "${branchName}"`;

        // Execute git command
        cp.exec(gitCommand, { cwd: cwd }, (err, stdout, stderr) => {
            if (err) {
                vscode.window.showErrorMessage(`Failed to create branch: ${stderr || err.message}`);
            } else {
                const action = shouldCheckout ? 'Created and checked out' : 'Created';
                vscode.window.showInformationMessage(`${action} branch: ${branchName}`);
            }
        });
    });

    context.subscriptions.push(disposable);
}

function deactivate() { }

module.exports = {
    activate,
    deactivate
}
