class String
  def underscore
    self.gsub(/([a-z])([A-Z])/) {|m| '%s_%s' % [m[0,1], m[1,1]]}.downcase
  end
end

class Array
  def last_match(&block)
    last_success=nil
    self.each do |e|
      if block.call(e)
        last_success = e
      else
        break
      end
    end
    last_success
  end
  
  def sum
    inject{|sum,e| sum+e}
  end
end