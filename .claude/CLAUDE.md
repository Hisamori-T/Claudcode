# Project Guidelines

## Multi-Agent Routing Rules

このプロジェクトでは3つの専門エージェントを使い分ける。

### Agent Routing

| トリガー | エージェント | モデル |
|---|---|---|
| 「計画して」「設計して」「タスク分解して」 | `planner` (Opus) | 計画・調査のみ。実装禁止。 |
| 「実装して」「作って」「修正して」 | `generator` (Sonnet) | 1タスクずつ実装。完了後 evaluator を必ず呼ぶ。 |
| 「レビューして」「評価して」「テストして」 | `evaluator` (Opus) | 品質チェック＋Playwright必須。不合格時は差し戻し。 |

### Workflow

```
User Request
    ↓
[Planner] → Sprint-Task-List.md を生成
    ↓
[Generator] → タスクを1つずつ実装 → 完了後 [Evaluator] を呼ぶ
    ↓
[Evaluator] → テスト＋レビュー
    ↓ PASS → 次のタスクへ
    ↓ FAIL → 具体的修正案を付けて [Generator] に差し戻し
```

### Rules

1. **Planner は実装しない。** Read / Glob / Grep のみ使用可。
2. **Generator は1回1タスク。** 複数タスクの同時実装は禁止。
3. **Generator は実装後に必ず Evaluator を呼ぶ。** 自己判断での完了は認めない。
4. **Evaluator は Playwright テストを必ず実行する。** テストなしでの合格判定は禁止。
5. **Evaluator の差し戻しには具体的修正案（コード例）を必ず含める。**

---

## State Management Protocol

エージェント間の文脈断絶を防ぐため、`.claudecode/state.json` で状態を一元管理する。

### state.json Schema

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
          "issues": ["Issue summary"],
          "timestamp": "ISO8601"
        }
      ]
    }
  ],
  "currentTask": "task-1",
  "lastAgent": "planner | generator | evaluator",
  "updatedAt": "ISO8601"
}
```

### State Read/Write Rules

1. **すべてのエージェントは起動時に `.claudecode/state.json` を必ず読む。**
   ファイルが存在しない場合は初期状態を作成する。
2. **すべてのエージェントは交代前に `.claudecode/state.json` を必ず更新する。**
   `lastAgent` と `updatedAt` は毎回更新すること。
3. **Planner**: スプリント情報とタスク一覧を書き込む。全タスクの `status` を `"pending"` で初期化する。
4. **Generator**: 着手時に `status` を `"in_progress"` に、実装完了時に `"in_review"` に変更する。
5. **Evaluator**: PASS時は `"passed"` に、FAIL時は `"failed"` に変更し、`evaluationHistory` に記録を追加する。

---

## Autonomous Loop Protocol

Generator と Evaluator は **自律ループ** で動作する。ユーザーへの報告は全タスク完了時のみ。

### Loop Flow

```
[Generator] タスク実装
    ↓ state.json 更新 (status: "in_review")
[Evaluator] 評価実行
    ↓
    ├─ FAIL → state.json 更新 (status: "failed")
    │         具体的修正案を付けて [Generator] に差し戻し
    │         → [Generator] が修正 → 再度 [Evaluator] へ（ループ）
    │
    └─ PASS → state.json 更新 (status: "passed")
              → currentTask を次のタスクに進める
              → 次のタスクがあれば [Generator] が自動着手（ループ）
              → 全タスク完了時のみユーザーに報告
```

### Autonomous Loop Rules

1. **Generator はタスク完了後、自動的に Evaluator を呼び出す。** 人間の介入を待たない。
2. **Evaluator が PASS と判定するまで、ユーザーに報告してはならない。**
   FAIL → 修正 → 再評価のサイクルはエージェント間で自律的に回す。
3. **同一タスクで3回連続 FAIL した場合のみ、ユーザーにエスカレーションする。**
   エスカレーション時は全試行の `evaluationHistory` を提示すること。
4. **全タスクが PASS になった時点で、ユーザーに最終報告を行う。**
   報告には完了タスク一覧・テスト結果サマリー・state.json の最終状態を含める。

---

## Fully Autonomous Execution

### Launch Command

```bash
claudecode --dangerously-skip-permissions
```

このフラグにより、ファイル書き込み・コマンド実行・ツール呼び出しすべてが **人間の承認なしに自動実行** される。
エージェントは完全な自走状態で動作し、Sprint-Task-List.md の全タスクが PASS するまで停止しない。

### Safety Guardrails（自走時の安全策）

自動化しても以下の安全策は維持する:

1. **Git ブランチ保護**: 作業は必ずフィーチャーブランチで行う。main/master への直接 push は禁止。
2. **3回 FAIL エスカレーション**: 同一タスクで3回連続 FAIL したら自動停止し、ユーザーに報告する。
3. **破壊的操作の禁止**: `rm -rf`, `git reset --hard`, `DROP TABLE` 等の破壊的コマンドは自走中でも実行しない。
4. **シークレット保護**: `.env`, 認証情報ファイルの読み書き・コミットは行わない。

---

## Visual Verification with Playwright MCP

Evaluator は Playwright MCP Server を通じてブラウザを直接操作し、**AIに目を持たせた** 視覚的検証を行う。

### Playwright MCP Setup

```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["@anthropic-ai/playwright-mcp@latest"],
      "env": {
        "DISPLAY": ":1"
      }
    }
  }
}
```

### Visual Verification Workflow

Evaluator は E2E テスト実行に加え、以下の視覚検証を必ず行う:

1. **ブラウザでページを開く** — Playwright MCP の `browser_navigate` でアプリにアクセス
2. **スクリーンショットを取得** — `browser_snapshot` / `browser_take_screenshot` で画面状態をキャプチャ
3. **UI要素の操作確認** — `browser_click`, `browser_type` 等で実際のユーザー操作を再現
4. **視覚的リグレッション検出** — レイアウト崩れ、文字化け、要素の非表示等を目視レベルで確認
5. **レスポンシブ確認** — `browser_resize` で複数ビューポートを検証

### Verdict に含める視覚証拠

```
### Visual Verification
- [x] ページ表示: 正常（スクリーンショット確認済み）
- [x] ユーザー操作: ボタンクリック → 期待通りの遷移
- [x] レスポンシブ: モバイル/デスクトップ両対応
- [ ] 問題発見: <具体的なUI不具合の説明>
```

---

## CI/CD Hooks Integration

ファイル保存時に自動で静的チェックを実行し、Generator に即座にフィードバックを返す。

### Hook Configuration

`.claude/settings.json` に以下のフックを定義する:

```json
{
  "hooks": {
    "afterWrite": [
      {
        "matcher": "**/*.{ts,tsx,js,jsx}",
        "command": "npx eslint --fix $FILE && npx tsc --noEmit 2>&1 | head -20"
      }
    ],
    "afterEdit": [
      {
        "matcher": "**/*.{ts,tsx,js,jsx}",
        "command": "npx eslint --fix $FILE && npx tsc --noEmit 2>&1 | head -20"
      }
    ]
  }
}
```

### Feedback Flow

```
Generator がファイルを Write/Edit
    ↓ (自動トリガー)
Hook: eslint --fix + tsc --noEmit
    ↓
    ├─ エラーあり → Generator に即座にフィードバック
    │               → Generator がその場で修正（Evaluator を待たない）
    │
    └─ エラーなし → 次の作業に進む
```

### Hook Rules

1. **Hook は Generator の作業中に自動実行される。** Generator は Hook の出力を無視してはならない。
2. **Hook でエラーが出た場合、Generator はその場で修正する。** Evaluator に渡す前にセルフチェックを通す。
3. **Hook は静的チェックのみ。** E2Eテストは Evaluator の責務であり、Hook では実行しない。
4. **Hook の修正は state.json に記録しない。** Hook 修正は実装の一部として扱う。
