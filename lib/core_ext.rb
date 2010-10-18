class String
  def underscore
    self.gsub(/([a-z])([A-Z])/) {|m| '%s_%s' % [m[0,1], m[1,1]]}.downcase
  end
end