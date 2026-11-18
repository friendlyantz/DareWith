class AddRepeatsToChallengeStories < ActiveRecord::Migration[8.1]
  def change
    add_column :challenge_stories, :repeats, :boolean, default: false, null: false
    add_index :challenge_stories, :repeats
  end
end
