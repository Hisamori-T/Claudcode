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
