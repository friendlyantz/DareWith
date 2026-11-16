class CreateBadges < ActiveRecord::Migration[8.1]
  def change
    create_enum :badge_kind, %w[first_check_in three_day_streak week_streak three_week_streak comeback finisher flawless cheerleader good_for_it]

    create_table :badges, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: {on_delete: :cascade}
      t.references :challenge_story, type: :uuid, foreign_key: {on_delete: :cascade}
      t.enum :kind, enum_type: :badge_kind, null: false
      t.timestamps

      t.index [:user_id, :kind, :challenge_story_id], unique: true, nulls_not_distinct: true
    end

    add_column :users, :badges_count, :integer, default: 0, null: false
  end
end
