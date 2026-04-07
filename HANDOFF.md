# Multi-Agent System 引き継ぎドキュメント

## 概要

Claude Code 上で動作する **3エージェント自律開発システム** を構築した。
ユーザーの指示を起点に、計画→実装→評価を自律的にループし、全タスクが合格するまで人間の介入なしに動作する。

---

## アーキテクチャ

```
ユーザー: 「○○を作って」
    ↓
┌─────────────────────────────────────────────────────────┐
│                    Claude Code                          │
│                                                         │
│  [Planner] ─── Sprint-Task-List.md を生成               │
│      │                                                   │
│      ▼                                                   │
│  [Generator] ─── タスクを1つ実装                         │
│      │               │                                   │
│      │          CI/CD Hook                               │
│      │          (eslint + tsc)                            │
│      │               │                                   │
│      ▼               ▼                                   │
│  [Evaluator] ─── Playwright E2E + 視覚検証              │
│      │                                                   │
│      ├─ FAIL → 修正案付きで Generator に差し戻し         │
│      │         （最大3回、超えたらユーザーに報告）        │
│      │                                                   │
│      └─ PASS → 次のタスクへ（全完了でユーザーに報告）    │
│                                                         │
│  [state.json] ─── エージェント間の状態共有               │
└─────────────────────────────────────────────────────────┘
```

---

## ファイル構成

```
.claude/
├── CLAUDE.md              # メインの指示書（全プロトコル定義）
├── settings.json          # Playwright MCP + CI/CD Hooks
└── agents/
    ├── planner.md         # Planner エージェント定義
    ├── generator.md       # Generator エージェント定義
    └── evaluator.md       # Evaluator エージェント定義

.claudecode/
└── state.json             # 実行時に自動生成される状態ファイル
```

---

## 3つのエージェント

### 1. Planner（計画専門 / Opus）

| 項目 | 内容 |
|------|------|
| 起動トリガー | 「計画して」「設計して」「タスク分解して」 |
| やること | コードベース調査 → `Sprint-Task-List.md` 生成 |
| 使えるツール | Read / Glob / Grep **のみ** |
| 禁止事項 | コードの生成・編集・書き込み |

**出力フォーマット（Sprint-Task-List.md）:**

```markdown
# Sprint Task List
## Goal
<スプリントの目標>
## Tasks
### Task 1: <タスク名>
- **Priority**: P0 / P1 / P2
- **Files**: 変更対象ファイル
- **Description**: 具体的な変更内容
- **Acceptance Criteria**:
  - [ ] 基準1
  - [ ] 基準2
- **Dependencies**: なし
```

### 2. Generator（実装専門 / Sonnet）

| 項目 | 内容 |
|------|------|
| 起動トリガー | 「実装して」「作って」「修正して」 |
| やること | Sprint-Task-List.md から **1タスクだけ** 実装 |
| 使えるツール | Read / Edit / Write / Bash（全ツール） |
| 禁止事項 | 複数タスクの同時実装、自己判断での完了宣言 |

**動作フロー:**
1. state.json を読み、現在のタスクを確認
2. 実装を行う
3. CI/CD Hook のフィードバック（eslint/tsc）があれば即修正
4. state.json を `in_review` に更新
5. **自動的に Evaluator を呼び出す**（人間の介入を待たない）

### 3. Evaluator（評価専門 / Opus）

| 項目 | 内容 |
|------|------|
| 起動トリガー | 「レビューして」「評価して」「テストして」 |
| やること | コードレビュー + Playwright E2E + 視覚検証 |
| 使えるツール | Read / Bash / Playwright MCP |
| 禁止事項 | コードの直接修正、テストなしでの合格判定 |

**チェック項目:**
- 静的解析（eslint, tsc）
- E2Eテスト（`npx playwright test`）
- 視覚検証（Playwright MCP でブラウザ操作 + スクリーンショット）
- コードレビュー（スタイル一貫性、スコープ外変更、エッジケース）
- レスポンシブ確認（375px / 768px / 1280px）

---

## 状態管理（state.json）

エージェント間の文脈断絶を防ぐための共有状態ファイル。

```json
{
  "sprint": {
    "number": 1,
    "goal": "スプリントの目標"
  },
  "tasks": [
    {
      "id": "task-1",
      "name": "タスク名",
      "status": "pending | in_progress | in_review | passed | failed",
      "assignedTo": "generator",
      "evaluationHistory": [
        {
          "attempt": 1,
          "verdict": "FAIL",
          "issues": ["問題の概要"],
          "timestamp": "2026-04-07T12:00:00Z"
        }
      ]
    }
  ],
  "currentTask": "task-1",
  "lastAgent": "planner",
  "updatedAt": "2026-04-07T12:00:00Z"
}
```

**ルール:**
- 全エージェントが起動時に読み、交代前に書く
- Planner: タスク一覧を `pending` で初期化
- Generator: `in_progress` → `in_review`
- Evaluator: `passed` or `failed`（+ evaluationHistory に記録追加）

---

## CI/CD Hooks

`.claude/settings.json` に定義済み。Generator がファイルを保存するたびに自動実行される。

| トリガー | 対象 | コマンド |
|----------|------|---------|
| afterWrite / afterEdit | `*.ts, *.tsx, *.js, *.jsx` | `npx eslint --fix $FILE && npx tsc --noEmit` |
| afterWrite / afterEdit | `*.css, *.scss` | `npx stylelint --fix $FILE` |

エラーが出たら Generator がその場で修正する（Evaluator を待たない）。

---

## Playwright MCP（視覚検証）

`.claude/settings.json` に MCP サーバーとして定義済み。

```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["@anthropic-ai/playwright-mcp@latest"],
      "env": { "DISPLAY": ":1" }
    }
  }
}
```

Evaluator が使用するツール:
- `browser_navigate` — ページを開く
- `browser_take_screenshot` — スクリーンショット取得
- `browser_click` / `browser_type` — ユーザー操作の再現
- `browser_resize` — レスポンシブ検証

---

## 自律実行モード

### 起動コマンド

```bash
claudecode --dangerously-skip-permissions
```

これにより全ツール呼び出しが人間の承認なしに自動実行される。

### 安全策

| ガードレール | 内容 |
|-------------|------|
| ブランチ保護 | main/master への直接 push 禁止。フィーチャーブランチのみ |
| 3回 FAIL | 同一タスク3回連続 FAIL → 自動停止 → ユーザーに報告 |
| 破壊的操作禁止 | `rm -rf`, `git reset --hard`, `DROP TABLE` 等は実行しない |
| シークレット保護 | `.env`, 認証情報の読み書き・コミット禁止 |

---

## 別の Claude Code セッションで使うには

### 方法 1: リポジトリを clone する（推奨）

```bash
git clone <このリポジトリのURL>
cd <リポジトリ名>
claudecode --dangerously-skip-permissions
```

`.claude/` ディレクトリがリポジトリに含まれているため、clone するだけで全設定が適用される。

### 方法 2: 別リポジトリにコピーする

```bash
# 対象リポジトリに .claude/ をコピー
cp -r <このリポジトリ>/.claude/ <対象リポジトリ>/.claude/
```

### 方法 3: グローバル設定にする

`~/.claude/CLAUDE.md` にルーティングルールを配置すると、全リポジトリで適用される。
ただし `.claude/agents/*.md` と `.claude/settings.json` は各リポジトリに配置が必要。

---

## 使用例

```
ユーザー: 「ログイン機能を計画して」
→ Planner が起動 → Sprint-Task-List.md を生成

ユーザー: 「実装して」
→ Generator が Sprint-Task-List.md のタスクを1つずつ実装
→ 各タスク完了後、自動で Evaluator を呼び出し
→ FAIL なら修正 → 再評価（自律ループ）
→ 全タスク PASS で初めてユーザーに報告
```

---

## コミット履歴

| コミット | 内容 |
|---------|------|
| `c15023d` | エージェント3体（planner/generator/evaluator）+ ルーティングルール |
| `f9b088e` | state.json 状態管理プロトコル + 自律ループプロトコル |
| `6fe309b` | 完全自動化 + Playwright MCP 視覚検証 + CI/CD Hooks |

ブランチ: `claude/setup-multi-agent-system-O2i8P`
