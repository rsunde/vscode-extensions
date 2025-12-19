const vscode = require('vscode');

/**
 * @param {import('vscode').ExtensionContext} context
 */
function activate(context) {
    const selector = { language: 'xml', pattern: '**/*.xaml' };

    /**
     * Extremely limited scope definition provider:
     * - XAML only
     * - {Binding PropertyName}
     * - DataContext from nearest ancestor: x:DataType or d:DesignInstance Type=
     * - Namespace from xmlns:prefix="clr-namespace:Foo.Bar"
     * - Resolve property via workspace symbol provider (best-effort)
     */
    const provider = {
        /**
         * @param {import('vscode').TextDocument} document
         * @param {import('vscode').Position} position
         * @returns {Promise<import('vscode').Location|null|import('vscode').Location[]>}
         */
        async provideDefinition(document, position) {
            try {
                if (!document || !document.uri) {
                    return null;
                }

                const fsPath = typeof document.uri.fsPath === 'string' ? document.uri.fsPath : '';
                if (!fsPath.toLowerCase().endsWith('.xaml')) {
                    return null;
                }

                const text = document.getText();
                const offset = document.offsetAt(position);

                const binding = findBindingAtOffset(text, offset);
                if (!binding) {
                    return null;
                }

                const dataType = findNearestDesignTimeDataType(document, position.line);
                if (!dataType) {
                    return null;
                }

                const xmlnsNamespace = findClrNamespaceForPrefix(text, dataType.prefix);
                if (!xmlnsNamespace) {
                    return null;
                }

                const fullTypeName = `${xmlnsNamespace}.${dataType.typeName}`;

                const propertyLocation = await findPropertyLocation(fullTypeName, dataType.typeName, binding.propertyName);
                if (!propertyLocation) {
                    return null;
                }

                return propertyLocation;
            }
            catch {
                return null;
            }
        }
    };

    context.subscriptions.push(
        vscode.languages.registerDefinitionProvider(selector, provider, '{', 'B')
    );
}

function deactivate() {}

module.exports = { activate, deactivate };

const BINDING_REGEX = /\{Binding\s+([A-Za-z_][A-Za-z0-9_]*)\}/g;
const XAML_IDENTIFIER_REGEX = /^[A-Za-z_][A-Za-z0-9_]*$/;
const PREFIX_REGEX = /^[A-Za-z_][\w\-]*$/;

const XDATA_TYPE_REGEX = /x:DataType="([^"]+)"/;
const DESIGN_INSTANCE_REGEX = /d:DataContext="\{d:DesignInstance\s+Type=([^}\s]+)\}"/;
const XMLNS_CLR_REGEX = /xmlns:([A-Za-z_][\w\-]*)="clr-namespace:([^";]+)(?:;assembly=[^";]+)?"/g;

/**
 * @param {string} text
 * @param {number} offset
 * @returns {{ propertyName: string } | null}
 */
function findBindingAtOffset(text, offset) {
    const windowRadius = 250;
    const windowStart = Math.max(0, offset - windowRadius);
    const windowEnd = Math.min(text.length, offset + windowRadius);
    const windowText = text.slice(windowStart, windowEnd);

    /** @type {{ propertyName: string } | null} */
    let found = null;

    BINDING_REGEX.lastIndex = 0;
    let match;
    // eslint-disable-next-line no-cond-assign
    while ((match = BINDING_REGEX.exec(windowText)) !== null) {
        const propertyName = match[1];
        if (!XAML_IDENTIFIER_REGEX.test(propertyName)) {
            continue;
        }

        const start = windowStart + match.index;
        const end = start + match[0].length;
        if (offset >= start && offset <= end) {
            if (found) {
                return null;
            }
            found = { propertyName };
        }
    }

    return found;
}

/**
 * Walk upward through lines and pick the closest line containing either:
 * - x:DataType="prefix:Type"
 * - d:DataContext="{d:DesignInstance Type=prefix:Type}"
 *
 * @param {import('vscode').TextDocument} document
 * @param {number} startLine
 * @returns {{ prefix: string, typeName: string } | null}
 */
function findNearestDesignTimeDataType(document, startLine) {
    for (let line = startLine; line >= 0; line--) {
        let text;
        try {
            text = document.lineAt(line).text;
        }
        catch {
            continue;
        }

        const xdt = XDATA_TYPE_REGEX.exec(text);
        XDATA_TYPE_REGEX.lastIndex = 0;
        const di = DESIGN_INSTANCE_REGEX.exec(text);
        DESIGN_INSTANCE_REGEX.lastIndex = 0;

        const candidates = [];
        if (xdt && typeof xdt[1] === 'string') {
            candidates.push(xdt[1]);
        }
        if (di && typeof di[1] === 'string') {
            candidates.push(di[1]);
        }

        if (candidates.length === 0) {
            continue;
        }
        if (candidates.length > 1) {
            return null;
        }

        const parsed = parsePrefixedType(candidates[0]);
        if (!parsed) {
            return null;
        }

        return parsed;
    }

    return null;
}

/**
 * @param {string} value
 * @returns {{ prefix: string, typeName: string } | null}
 */
function parsePrefixedType(value) {
    const trimmed = value.trim();
    const parts = trimmed.split(':');
    if (parts.length !== 2) {
        return null;
    }

    const prefix = parts[0];
    const typeName = parts[1];
    if (!PREFIX_REGEX.test(prefix)) {
        return null;
    }
    if (!XAML_IDENTIFIER_REGEX.test(typeName)) {
        return null;
    }

    return { prefix, typeName };
}

/**
 * @param {string} documentText
 * @param {string} prefix
 * @returns {string | null}
 */
function findClrNamespaceForPrefix(documentText, prefix) {
    if (!prefix || !PREFIX_REGEX.test(prefix)) {
        return null;
    }

    /** @type {Set<string>} */
    const namespaces = new Set();

    XMLNS_CLR_REGEX.lastIndex = 0;
    let match;
    // eslint-disable-next-line no-cond-assign
    while ((match = XMLNS_CLR_REGEX.exec(documentText)) !== null) {
        const foundPrefix = match[1];
        const clrNs = match[2];
        if (foundPrefix === prefix && typeof clrNs === 'string' && clrNs.length > 0) {
            namespaces.add(clrNs);
        }
    }

    if (namespaces.size !== 1) {
        return null;
    }

    return Array.from(namespaces)[0];
}

/**
 * @param {string | undefined} containerName
 * @param {string} fullTypeName
 * @param {string} typeName
 */
function containerMatches(containerName, fullTypeName, typeName) {
    if (!containerName) {
        return false;
    }

    if (containerName === fullTypeName) {
        return true;
    }

    if (containerName === typeName) {
        return true;
    }

    return containerName.endsWith(`.${typeName}`);
}

/**
 * Best-effort: use the workspace symbol provider to locate the property.
 * Abort if ambiguous.
 *
 * @param {string} fullTypeName
 * @param {string} typeName
 * @param {string} propertyName
 * @returns {Promise<import('vscode').Location | null>}
 */
async function findPropertyLocation(fullTypeName, typeName, propertyName) {
    if (!XAML_IDENTIFIER_REGEX.test(propertyName)) {
        return null;
    }

    // Step 1: resolve the type symbol (abort if ambiguous)
    const typeSymbol = await findTypeSymbol(fullTypeName, typeName);
    if (!typeSymbol) {
        return null;
    }

    // Step 2: resolve the property symbol
    const queries = [
        `${fullTypeName}.${propertyName}`,
        `${typeName}.${propertyName}`,
        propertyName
    ];

    for (const q of queries) {
        /** @type {any} */
        let symbols;
        try {
            symbols = await vscode.commands.executeCommand('vscode.executeWorkspaceSymbolProvider', q);
        }
        catch {
            return null;
        }

        if (!Array.isArray(symbols) || symbols.length === 0) {
            continue;
        }

        const candidates = symbols
            .filter(s => s && s.kind === vscode.SymbolKind.Property)
            .filter(s => s.name === propertyName)
            .filter(s => containerMatches(s.containerName, fullTypeName, typeName));

        const unique = uniqueByLocation(candidates);
        if (unique.length === 1) {
            return unique[0].location;
        }
        if (unique.length > 1) {
            return null;
        }
    }

    // If we couldn't resolve a property, abort silently.
    return null;
}

/**
 * @param {string} fullTypeName
 * @param {string} typeName
 * @returns {Promise<any|null>}
 */
async function findTypeSymbol(fullTypeName, typeName) {
    const typeQueries = [fullTypeName, typeName];
    for (const q of typeQueries) {
        /** @type {any} */
        let symbols;
        try {
            symbols = await vscode.commands.executeCommand('vscode.executeWorkspaceSymbolProvider', q);
        }
        catch {
            return null;
        }

        if (!Array.isArray(symbols) || symbols.length === 0) {
            continue;
        }

        const candidates = symbols.filter(s => {
            if (!s) {
                return false;
            }

            const isTypeKind =
                s.kind === vscode.SymbolKind.Class ||
                s.kind === vscode.SymbolKind.Struct ||
                s.kind === vscode.SymbolKind.Interface ||
                s.kind === vscode.SymbolKind.Enum;

            if (!isTypeKind) {
                return false;
            }

            if (s.name === typeName) {
                return true;
            }

            // Some servers may return fully qualified names in name.
            if (s.name === fullTypeName) {
                return true;
            }

            return false;
        });

        const unique = uniqueByLocation(candidates);
        if (unique.length === 1) {
            return unique[0];
        }
        if (unique.length > 1) {
            return null;
        }
    }

    return null;
}

/**
 * @param {any[]} symbols
 */
function uniqueByLocation(symbols) {
    /** @type {Map<string, any>} */
    const map = new Map();
    for (const s of symbols) {
        if (!s || !s.location || !s.location.uri || !s.location.range) {
            continue;
        }
        const uri = s.location.uri.toString();
        const start = s.location.range.start;
        const key = `${uri}:${start.line}:${start.character}`;
        if (!map.has(key)) {
            map.set(key, s);
        }
    }
    return Array.from(map.values());
}
