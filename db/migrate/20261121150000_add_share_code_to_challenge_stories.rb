# Short invite links: darewith.app/c/k3Fx9aQm instead of the story's UUID
class AddShareCodeToChallengeStories < ActiveRecord::Migration[8.1]
  BASE58 = [*"1".."9", *"A".."H", *"J".."N", *"P".."Z", *"a".."k", *"m".."z"].freeze

  def up
    add_column :challenge_stories, :share_code, :string

    select_values("SELECT id FROM challenge_stories").each do |id|
      execute "UPDATE challenge_stories SET share_code = #{quote(SecureRandom.alphanumeric(8, chars: BASE58))} WHERE id = #{quote(id)}"
    end

    change_column_null :challenge_stories, :share_code, false
    add_index :challenge_stories, :share_code, unique: true
  end

  def down
    remove_column :challenge_stories, :share_code
  end
end
