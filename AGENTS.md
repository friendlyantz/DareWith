# AGENTS.md

Rails 8 app. Write code so simple it reads like documentation. Trust Rails conventions, name things after the domain (`ChallengeCheckIn`, not `Entry`), avoid architecture for its own sake.

## Stack

Rails 8.1, Postgres, Puma, Propshaft, importmap, Turbo + Stimulus, tailwindcss-rails + daisyUI 5, Solid Queue/Cache/Cable, WebAuthn (passkeys), Kamal. Tests: RSpec, FactoryBot, Capybara + Cuprite, SitePrism. Lint: `standard`, `erb_lint`.

**Don't add gems without asking.** Never use: service objects (`app/services/`), contexts/operations/interactors, result objects, Devise, CanCanCan, ActiveAdmin, state-machine gems, dry-types/Virtus/reform, Faraday/RestClient.

## Where code goes

| What | Where |
|---|---|
| Simple check/query | model method or scope |
| Logic > ~15 lines, external API, complex calc | namespaced model class, e.g. `app/models/challenge_participant/streak.rb` |
| Async or multi-step workflow | job (orchestrates; model classes do the work) |
| Create/update several models at once | form object in `app/forms/` |
| Complex reusable query | query object `Model::SomethingQuery` |
| Auth / scoping | namespaced controller inheriting a base (`Admin::ApplicationController`) — not a concern |

No concerns for business logic. Inheritance or delegation instead.

## Models

Order: DSL extensions → associations → enums → `normalizes` → validations → scopes → callbacks → delegates → public methods → private methods.

- State lives in enums, backed by Postgres `create_enum`: `enum :status, %w[active inactive].index_by(&:itself)`.
- Use `normalizes` for cleanup (`normalizes :email, with: -> { it.strip.downcase }`).
- Every `has_many` gets a counter cache where counts are shown.
- Callbacks only for trivial self-contained things (defaults, tokens). Never workflows (enqueue jobs, send mail) in callbacks.
- Keep models under ~100 lines; extract to namespaced classes.

Namespaced classes: `private attr_reader`, one public verb method, return plain values (IO, string, boolean, record), raise on error. No hashes or result structs.

## Controllers

- 5–10 lines per action: guard clauses, one model operation, enqueue job, redirect/render.
- Guard clauses over nested conditionals: `return head 422 unless ...`.
- No business logic, data transformation, or multi-model writes (use a form object).

## Database

- Normalize: one concern per table.
- `null: false`, foreign keys (`on_delete: :cascade` where appropriate), check constraints for invariants.
- Index foreign keys, enum columns, and anything scopes filter on.

## Jobs

Jobs orchestrate, model classes execute. For multi-step work use `ActiveJob::Continuable` with `step :name`. In each step: update state, `rescue => err`, `Rails.error.report(err, handled: true)`, mark the record failed. Broadcast progress with `Turbo::StreamsChannel.broadcast_refresh_to(record)`.

## Views & frontend

- Hotwire only, no SPA. Stimulus controllers in `app/javascript/controllers/`.
- Views use associations/scopes only; no query logic or filtering in ERB. Avoid N+1 with `includes`.
- Styling: daisyUI component classes + Tailwind utilities, daisyUI semantic colors (`bg-base-200`, `text-primary`) rather than raw Tailwind colors, responsive prefixes on `flex`/`grid`, no custom CSS. Theme config is in `app/assets/tailwind/`. No `tailwind.config.js`.
- Full daisyUI 5 class reference: `daisyui.md`. Read only the section for the component you need (grep for `### <component>`).

## Testing

RSpec only. `spec/models`, `spec/requests`, `spec/system`, `spec/factories`. Test custom validations, business logic, HTTP responses and critical flows. Don't test framework behaviour (associations, plain CRUD, callbacks).

```bash
bundle exec rspec
bundle exec standardrb --fix
```

## Checklist

Domain naming · right layer · enum state · thin controller · extracted complex logic · constraints + FKs + indexes · counter caches · RSpec coverage of business logic.
