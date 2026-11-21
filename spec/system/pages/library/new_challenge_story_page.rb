# frozen_string_literal: true

class Library::NewChallengeStoryPage < BasePage
  set_url "/challenge_stories/new"

  element :title_field, 'input[name="challenge_story[title]"]'
  element :description_field, 'textarea[name="challenge_story[description]"]'
  element :start_field, 'input[name="challenge_story[start]"]'
  element :finish_field, 'input[name="challenge_story[finish]"]'
  element :cadence_field, 'select[name="challenge_story[cadence]"]'
  element :length_dates, '[data-challenge-length-target="dates"]'
  element :unit_field, 'select[name="challenge_story[unit]"]'
  element :target_amount_field, 'input[name="challenge_story[target_amount]"]'
  element :penalty_field, 'input[name="challenge_story[penalty]"]'
  element :goal_summary, '[data-challenge-goal-target="summary"]'
  element :submit_button, 'button[type="submit"]'

  def fill_form(title:, start_date:, finish_date:, description: nil)
    title_field.set(title)
    add_note(description) if description
    choose_length("Custom")
    start_field.set(start_date.to_s)
    finish_field.set(finish_date.to_s)
  end

  def choose_length(label)
    choose(label, allow_label_click: true)
  end

  def set_penalty(mode, owed)
    find("summary", text: "If someone misses").click
    choose(mode, allow_label_click: true)
    penalty_field.set(owed)
  end

  def add_note(text)
    find("summary", text: "What counts?").click
    description_field.set(text)
  end

  def submit
    submit_button.click
  end
end
