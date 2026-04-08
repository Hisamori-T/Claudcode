# Session Log

## 概要

このドキュメントは `Hisamori-T/Claudcode` リポジトリの構築作業の引き継ぎ記録です。
新しいセッションを開始する際はここから読み始めてください。

---

## 目的

**どのPCからでも、同じアカウントであれば同じClaude Code設定を適用する**

- 全てWindows環境
- Google Drive（`G:\マイドライブ\antigravity\Claudcode\`）を同期媒体として使用
- `setup.ps1` を1回実行するだけで新PCにセットアップ完了

---

## リポジトリ構成

```
Claudcode/
  claude-config/          → ~/.claude/ にシンボリックリンク or コピーされる
    settings.json         Claude Code のグローバル設定
    CLAUDE.md             マルチエージェントシステムのガイドライン
    agents/
      planner.md          Plannerエージェント定義（Opus）
      generator.md        Generatorエージェント定義（Sonnet）
      evaluator.md        Evaluatorエージェント定義（Opus）
  melta-ui-main/          デザインシステム SSOT
  vscode/
    settings.json         VSCode ユーザー設定（setup.ps1 でマージ）
  docs/
    sessionlog.md         ← このファイル
  setup.ps1               新PC用セットアップスクリプト
```

---

## 確立されたルール

### Claude Code 設定（`claude-config/settings.json`）

| 設定 | 値 | 目的 |
|---|---|---|
| `permissions.defaultMode` | `bypassPermissions` | YES/NOボタンを全廃止 |
| `skipDangerousModePermissionPrompt` | `true` | 危険モード確認ダイアログを非表示 |
| hooks `afterWrite/afterEdit` | eslint + tsc / stylelint | ファイル保存時に自動lint |
| mcpServers `playwright` | `@anthropic-ai/playwright-mcp@latest` | Evaluatorの視覚検証用 |

**補足**: `bypassPermissions` はUI上のモード選択には表示されないが、`settings.json` に直接書けば動作する。VSCode拡張でも `~/.claude/settings.json` を共通で読む。反映には **VSCode再起動** または `Ctrl+Shift+P` → `Developer: Reload Window` が必要。

### VSCode 設定（`vscode/settings.json`）

| 設定 | 値 |
|---|---|
| `files.autoSave` | `afterDelay` (500ms) |
| `security.workspace.trust.enabled` | `false` |
| `terminal.integrated.confirmOnExit/Kill` | `never` |

**注意**: `claudeCode.environmentVariables: [{autoApprove: true}]` は無効な書き方のため削除済み。

### マルチエージェントシステム（`claude-config/agents/`）

3エージェント自律開発システム：

| エージェント | モデル | 役割 |
|---|---|---|
| `planner` | Opus | 要件解析 → `Sprint-Task-List.md` 生成。実装禁止 |
| `generator` | Sonnet | 1タスクずつ実装 → 完了後 evaluator を自動呼び出し |
| `evaluator` | Opus | E2E・視覚検証・DS監査 → PASS/REJECT判定 |

**状態管理**: `.claudecode/state.json` でスプリント・タスク・判定結果を永続化  
**自律性**: ユーザーへの報告は全タスク完了時のみ。3回連続REJECT でエスカレーション

### デザインシステム SSOT（`melta-ui-main/`）

- `melta-ui-main/CLAUDE.md` — クイックリファレンス（全エージェントが最初に読む）
- `melta-ui-main/foundations/prohibited.md` — 全禁止パターン（76項目）のSSot
- `melta-ui-main/tokens/tokens.json` — デザイントークン
- `melta-ui-main/components/` — 28コンポーネント定義
- `melta-ui-main/skills/design-review/` — DSチェックスキル

**主要禁止パターン**: `text-black`、`shadow-lg/2xl`、`border-t-4/border-l-4` カラーバー、`bg-indigo-*` ハードコードカラー、`border-gray-100` など

---

## 新PCのセットアップ手順

### setup.ps1 の実行方法

**方法1: PowerShellコマンドで実行**

```powershell
# Win + R → powershell → Enter して以下を貼り付け
powershell -ExecutionPolicy Bypass -File "G:\マイドライブ\antigravity\Claudcode\setup.ps1"
```

**方法2: エクスプローラーから実行**

`setup.ps1` を右クリック → **「PowerShellで実行」**（ExecutionPolicy が既に緩い場合）

**実行後**

1. VSCode を再起動（または `Ctrl+Shift+P` → `Developer: Reload Window`）

シンボリックリンクモード（開発者モード有効時）は `git pull` するだけで即反映。  
コピーモードの場合は `setup.ps1` 再実行が必要。

---

## 作業履歴

| 日付 | 作業内容 |
|---|---|
| 2026-04-07 | リポジトリ初期構築（claude-config/、vscode/、setup.ps1、melta-ui-main/） |
| 2026-04-07 | GitHub `Hisamori-T/Claudcode` main ブランチに初回 push |
| 2026-04-07 | エージェント定義をmelta-ui実体に合わせて更新（パス修正、prohibited.md反映） |
| 2026-04-07 | `bypassPermissions` + `skipDangerousModePermissionPrompt` でYESボタン廃止 |
| 2026-04-07 | VSCode settings から無効キー削除、enum値修正 |
| 2026-04-08 | `bypassPermissions` が UI に表示されない件を確認。settings.json 直書きで対応済み |
| 2026-04-08 | docs/sessionlog.md 作成（本ファイル） |

---

## 未解決・次のアクション候補

- [ ] `setup.ps1` を実際に新PCで実行してシンボリックリンクの動作確認
- [ ] 具体的なアプリプロジェクトを決めて Planner を起動する（製品仕様書の策定）
- [ ] `melta-ui-main/.mcp.json` の MCP サーバー設定をClaude Code側に統合するか検討
