module RequestSpecHelper
  def json_response
    JSON.parse(response.body, symbolize_names: true)
  end

  def auth_headers(student)
    token = JwtService.encode(student_id: student.id)
    { 'Authorization' => "Bearer #{token}" }
  end

  def parent_auth_headers(parent)
    token = JwtService.encode(parent_id: parent.id)
    { 'Authorization' => "Bearer #{token}" }
  end

  def admin_headers
    { 'X-Admin-Token' => ENV['ADMIN_TOKEN'] || 'test-admin-token' }
  end
end


