# Global Claude Code Guidelines

## Design System SSOT

**`melta-ui-main/` が唯一の真実（Single Source of Truth）**

- 起動時に必ず `melta-ui-main/CLAUDE.md` のクイックリファレンスを参照すること
- 全エージェントはデザイン判断の根拠を `melta-ui-main/` に求めること
- 「いい感じ」の独自デザイン生成は**全面禁止**

## Multi-Agent Routing

| トリガーワード | エージェント | モデル | 役割 |
|---|---|---|---|
| 「計画」「設計」「タスク分解」「調査」 | `planner` | Opus | 計画・調査のみ。実装禁止 |
| 「実装」「作成」「修正」「追加」 | `generator` | Sonnet | 1タスクずつ実装。完了後 evaluator を呼び出す |
| 「レビュー」「評価」「テスト」「確認」 | `evaluator` | Opus | 品質チェック・デザイン監査。Playwright必須 |

## State Management

エージェント間の状態は `.claudecode/state.json` で共有・永続化する。

```json
{
  "sprint": { "number": 1, "goal": "スプリント目標" },
  "tasks": [
    {
      "id": "task-1",
      "name": "タスク名",
      "status": "pending|in_progress|in_review|passed|failed",
      "evaluatorVerdict": "PASS|REJECT|null",
      "rejectCount": 0
    }
  ],
  "currentTask": "task-1",
  "lastAgent": "planner|generator|evaluator",
  "updatedAt": "ISO8601"
}
```

全エージェントは起動時に state.json を読み、ハンドオフ前に更新すること。

## Autonomous Loop

- Generator → Evaluator（PASS / REJECT）→ 次タスク または 自己修復
- **ユーザーへの報告は全タスク完了時のみ**（途中経過を報告しない）
- 3回連続 REJECT でユーザーへエスカレーション

## CI/CD Hooks

ファイル書き込み後に eslint + tsc が自動実行される。Generator はフックのエラーを即座に修正し、Evaluator に渡す前に解消すること。

## Safety Guardrails

- main/master への直接 push 禁止
- 破壊的操作（rm -rf, DROP TABLE 等）禁止
- シークレットファイル（.env 等）の編集禁止
- 3回連続失敗で自動停止
