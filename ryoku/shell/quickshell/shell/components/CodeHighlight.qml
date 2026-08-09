import QtQuick
import org.kde.syntaxhighlighting

// KSyntaxHighlighting bound to a code TextEdit, isolated in its own file so the
// chat can load it through a Loader. A machine missing the org.kde.
// syntaxhighlighting QML module (the `syntax-highlighting` package) fails only
// this Loader and keeps plain, readable code blocks, instead of failing the
// whole chat panel on a hard import. The host sets `textEdit` and `lang`.
SyntaxHighlighter {
    property string lang: "plaintext"
    repository: Repository
    definition: Repository.definitionForName(lang && lang.length ? lang : "plaintext")
    theme: "Monokai"
}
