module Retention
  class SubjectRecommendations
    # Mapping of completed subjects to recommended next subjects
    RECOMMENDATIONS = {
      'sat_prep' => {
        next_subjects: ['college_essays', 'study_skills', 'ap_courses', 'act_prep'],
        message: "Great job completing SAT prep! Many students find success continuing with college application support.",
        priority_order: ['college_essays', 'ap_courses', 'study_skills']
      },
      'act_prep' => {
        next_subjects: ['college_essays', 'study_skills', 'sat_prep', 'ap_courses'],
        message: "ACT prep complete! Consider getting help with college essays or AP courses.",
        priority_order: ['college_essays', 'ap_courses']
      },
      'chemistry' => {
        next_subjects: ['physics', 'biology', 'ap_chemistry', 'organic_chemistry'],
        message: "Chemistry mastered! Physics and biology are natural next steps for STEM success.",
        priority_order: ['physics', 'ap_chemistry', 'biology']
      },
      'physics' => {
        next_subjects: ['ap_physics', 'chemistry', 'calculus', 'engineering_prep'],
        message: "Physics complete! Consider AP Physics or strengthen your calculus foundation.",
        priority_order: ['ap_physics', 'calculus']
      },
      'algebra' => {
        next_subjects: ['geometry', 'algebra_2', 'pre_calculus', 'trigonometry'],
        message: "Algebra mastered! You're ready to tackle geometry or move to Algebra 2.",
        priority_order: ['geometry', 'algebra_2']
      },
      'geometry' => {
        next_subjects: ['algebra_2', 'trigonometry', 'pre_calculus'],
        message: "Geometry complete! Algebra 2 or trigonometry is your next math milestone.",
        priority_order: ['algebra_2', 'trigonometry']
      },
      'calculus' => {
        next_subjects: ['ap_calculus', 'statistics', 'linear_algebra', 'physics'],
        message: "Calculus done! AP Calculus or statistics will strengthen your math foundation.",
        priority_order: ['ap_calculus', 'statistics']
      },
      'biology' => {
        next_subjects: ['chemistry', 'ap_biology', 'anatomy', 'environmental_science'],
        message: "Biology mastered! Chemistry pairs perfectly, or dive deeper with AP Biology.",
        priority_order: ['chemistry', 'ap_biology']
      },
      'english' => {
        next_subjects: ['ap_english', 'creative_writing', 'sat_reading', 'literature'],
        message: "English skills strong! Consider AP English or focus on SAT reading.",
        priority_order: ['ap_english', 'sat_reading']
      },
      'spanish' => {
        next_subjects: ['ap_spanish', 'spanish_literature', 'french', 'latin'],
        message: "¡Muy bien! Ready for AP Spanish or explore another language?",
        priority_order: ['ap_spanish', 'french']
      }
    }.freeze

    def self.get_recommendations(subject)
      normalized = subject.to_s.downcase.gsub(/\s+/, '_')
      RECOMMENDATIONS[normalized] || default_recommendations(subject)
    end

    def self.default_recommendations(subject)
      {
        next_subjects: ['study_skills', 'test_prep', 'writing'],
        message: "Congratulations on completing #{subject}! Here are some ways to continue learning.",
        priority_order: ['study_skills', 'test_prep']
      }
    end
  end
end


