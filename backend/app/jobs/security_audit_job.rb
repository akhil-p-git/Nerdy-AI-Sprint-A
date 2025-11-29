class SecurityAuditJob < ApplicationJob
  queue_as :low

  def perform
    audit_results = {
      timestamp: Time.current,
      checks: []
    }

    # Check for users without recent password changes (if applicable)
    audit_results[:checks] << check_password_age

    # Check for unusual login patterns
    audit_results[:checks] << check_login_patterns

    # Check for rate limit violations
    audit_results[:checks] << check_rate_limit_violations

    # Check for failed authentication attempts
    audit_results[:checks] << check_failed_auth_attempts

    # Check for sensitive data exposure
    audit_results[:checks] << check_sensitive_data_logs

    # Store audit results
    SecurityAuditLog.create!(
      audit_type: 'scheduled',
      results: audit_results,
      status: audit_results[:checks].all? { |c| c[:status] == 'pass' } ? 'pass' : 'warning'
    )

    # Alert if issues found
    alert_security_team(audit_results) if audit_results[:checks].any? { |c| c[:status] == 'fail' }
  end

  private

  def check_password_age
    # Placeholder - implement based on auth system
    { name: 'password_age', status: 'pass', details: 'Using JWT authentication' }
  end

  def check_login_patterns
    suspicious_ips = REDIS.keys('rate_limit:auth:ip:*').select do |key|
      REDIS.get(key).to_i > 10
    end

    {
      name: 'login_patterns',
      status: suspicious_ips.any? ? 'warning' : 'pass',
      details: "#{suspicious_ips.length} IPs with multiple auth attempts"
    }
  end

  def check_rate_limit_violations
    violations = REDIS.keys('rate_limit:*').count do |key|
      REDIS.get(key).to_i >= 100
    end

    {
      name: 'rate_limits',
      status: violations > 10 ? 'warning' : 'pass',
      details: "#{violations} rate limit violations in last hour"
    }
  end

  def check_failed_auth_attempts
    failed_count = REDIS.get('auth:failed:count').to_i

    {
      name: 'failed_auth',
      status: failed_count > 100 ? 'warning' : 'pass',
      details: "#{failed_count} failed auth attempts today"
    }
  end

  def check_sensitive_data_logs
    # Check if sensitive data appears in logs
    log_file = Rails.root.join('log', "#{Rails.env}.log")
    return { name: 'sensitive_logs', status: 'pass', details: 'Log file not found' } unless File.exist?(log_file)

    sensitive_patterns = [
      /password["\s:=]+\w+/i,
      /api_key["\s:=]+\w+/i,
      /secret["\s:=]+\w+/i
    ]

    recent_logs = `tail -1000 #{log_file}`
    found = sensitive_patterns.any? { |p| recent_logs.match?(p) }

    {
      name: 'sensitive_logs',
      status: found ? 'fail' : 'pass',
      details: found ? 'Potential sensitive data in logs' : 'No sensitive data found'
    }
  end

  def alert_security_team(results)
    # Send alert via email, Slack, or PagerDuty
    Rails.logger.warn("Security audit found issues: #{results.to_json}")
  end
end


