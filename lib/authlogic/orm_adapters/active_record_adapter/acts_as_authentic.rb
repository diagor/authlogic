module Authlogic
  module ORMAdapters # :nodoc:
    module ActiveRecordAdapter # :nodoc:
      # = Acts As Authentic
      # Provides the acts_as_authentic method to include in your models to help with authentication. See method below.
      module ActsAsAuthentic
        # Call this method in your model to add in basic authentication madness that your authlogic session expects.
        #
        # === Methods
        # For example purposes lets assume you have a User model.
        #
        #   Class method name           Description
        #   User.crypto_provider        The class that you set in your :crypto_provider option
        #   User.forget_all!            Finds all records, loops through them, and calls forget! on each record. This is paginated to save on memory.
        #   User.unique_token           returns unique token generated by your :crypto_provider
        #
        #   Named Scopes
        #   User.logged_in              Find all users who are logged in, based on your :logged_in_timeout option.
        #   User.logged_out             Same as above, but logged out.
        #
        #   Isntace method name
        #   user.password=              Method name based on the :password_field option. This is used to set the password. Pass the *raw* password to this.
        #   user.confirm_password=      Confirms the password, needed to change the password.
        #   user.valid_password?(pass)  Determines if the password passed is valid. The password could be encrypted or raw.
        #   user.reset_password!        Basically resets the password to a random password using only letters and numbers.
        #   user.logged_in?             Based on the :logged_in_timeout option. Tells you if the user is logged in or not.
        #   user.forget!                Changes their remember token, making their cookie and session invalid. A way to log the user out withouth changing their password.
        #
        # === Options
        #
        # * <tt>session_class:</tt> default: "#{name}Session",
        #   This is the related session class. A lot of the configuration will be based off of the configuration values of this class.
        #   
        # * <tt>crypto_provider:</tt> default: Authlogic::Sha512CryptoProvider,
        #   This is the class that provides your encryption. By default Authlogic provides its own crypto provider that uses Sha512 encrypton.
        #   
        # * <tt>login_field:</tt> default: options[:session_class].login_field,
        #   The name of the field used for logging in, this is guess based on what columns are in your db. Only specify if you aren't using:
        #   login, username, or email
        #   
        # * <tt>login_field_type:</tt> default: options[:login_field] == :email ? :email : :login,
        #   Tells authlogic how to validation the field, what regex to use, etc. If the field name is email it will automatically use email,
        #   otherwise it uses login.
        #   
        # * <tt>login_field_regex:</tt> default: if email then typical email regex, otherwise typical login regex.
        #   This is used in validates_format_of for the login_field.
        #   
        # * <tt>login_field_regex_message:</tt> the message to use when the validates_format_of for the login field fails.
        #   
        # * <tt>password_field:</tt> default: options[:session_class].password_field,
        #   This is the name of the field to set the password, *NOT* the field the encrypted password is stored.
        #   
        # * <tt>crypted_password_field:</tt> default: depends on which columns are present,
        #   The name of the database field where your encrypted password is stored. If the name of the field is different from any of the following
        #   you need to specify it with this option: crypted_password, encrypted_password, password_hash, pw_hash
        #   
        # * <tt>password_salt_field:</tt> default: depends on which columns are present,
        #   This is the name of the field in your database that stores your password salt. If the name of the field is different from any of the
        #   following then you need to specify it with this option: password_salt, pw_salt, salt
        #   
        # * <tt>remember_token_field:</tt> default: options[:session_class].remember_token_field,
        #   This is the name of the field your remember_token is stored. The remember token is a unique token that is stored in the users cookie and
        #   session. This way you have complete control of when session expire and you don't have to change passwords to expire sessions. This also
        #   ensures that stale sessions can not be persisted. By stale, I mean sessions that are logged in using an outdated password. If the name
        #   of the field is anything other than the following you need to specify it with this option: remember_token, remember_key, cookie_token,
        #   cookie_key
        #   
        # * <tt>scope:</tt> default: nil,
        #   This scopes validations. If all of your users belong to an account you might want to scope everything to the account. Just pass :account_id
        #   
        # * <tt>logged_in_timeout:</tt> default: 10.minutes,
        #   This is really just a nifty feature to tell if a user is logged in or not. It's based on activity. So if the user in inactive longer than
        #   the value you pass here they are assumed "logged out".
        #
        # * <tt>session_ids:</tt> default: [nil],
        #   The sessions that we want to automatically reset when a user is created or updated so you don't have to worry about this. Set to [] to disable.
        #   Should be an array of ids. See the Authlogic::Session documentation for information on ids. The order is important.
        #   The first id should be your main session, the session they need to log into first. This is generally nil. When you don't specify an id
        #   in your session you are really just inexplicitly saying you want to use the id of nil.
        def acts_as_authentic(options = {})
          # If we don't have a database, skip all of this, solves initial setup errors
          begin
            column_names
          rescue Exception
            return
          end
        
          # Setup default options
          begin
            options[:session_class] ||= "#{name}Session".constantize
          rescue NameError
            raise NameError.new("You must create a #{name}Session class before a model can act_as_authentic. If that is not the name of the class pass the class constant via the :session_class option.")
          end
        
          options[:crypto_provider] ||= Sha512CryptoProvider
          options[:crypto_provider_type] ||= options[:crypto_provider].respond_to?(:decrypt) ? :encryption : :hash
          options[:login_field] ||= options[:session_class].login_field
          options[:login_field_type] ||= options[:login_field] == :email ? :email : :login
          options[:password_field] ||= options[:session_class].password_field
          options[:crypted_password_field] ||=
            (column_names.include?("crypted_password") && :crypted_password) ||
            (column_names.include?("encrypted_password") && :encrypted_password) ||
            (column_names.include?("password_hash") && :password_hash) ||
            (column_names.include?("pw_hash") && :pw_hash) ||
            :crypted_password
          options[:password_salt_field] ||= 
            (column_names.include?("password_salt") && :password_salt) ||
            (column_names.include?("pw_salt") && :pw_salt) ||
            (column_names.include?("salt") && :salt) ||
            :password_salt
          options[:remember_token_field] ||= options[:session_class].remember_token_field
          options[:logged_in_timeout] ||= 10.minutes
          options[:session_ids] ||= [nil]
      
          # Validations
          case options[:login_field_type]
          when :email
            validates_length_of options[:login_field], :within => 6..100
            email_name_regex  = '[\w\.%\+\-]+'
            domain_head_regex = '(?:[A-Z0-9\-]+\.)+'
            domain_tld_regex  = '(?:[A-Z]{2}|com|org|net|edu|gov|mil|biz|info|mobi|name|aero|jobs|museum)'
            options[:login_field_regex] ||= /\A#{email_name_regex}@#{domain_head_regex}#{domain_tld_regex}\z/i
            options[:login_field_regex_message] ||= "should look like an email address."
            validates_format_of options[:login_field], :with => options[:login_field_regex], :message => options[:login_field_regex_message]
          else
            validates_length_of options[:login_field], :within => 2..100
            options[:login_field_regex] ||= /\A\w[\w\.\-_@ ]+\z/
            options[:login_field_regex_message] ||= "use only letters, numbers, spaces, and .-_@ please."
            validates_format_of options[:login_field], :with => options[:login_field_regex], :message => options[:login_field_regex_message]
          end
      
          validates_uniqueness_of options[:login_field], :scope => options[:scope]
          validates_uniqueness_of options[:remember_token_field]
          validate :validate_password
          validates_numericality_of :login_count, :only_integer => :true, :greater_than_or_equal_to => 0, :allow_nil => true if column_names.include?("login_count")
      
          if column_names.include?("last_request_at")
            named_scope :logged_in, lambda { {:conditions => ["last_request_at > ?", options[:logged_in_timeout].ago]} }
            named_scope :logged_out, lambda { {:conditions => ["last_request_at is NULL or last_request_at <= ?", options[:logged_in_timeout].ago]} }
          end
      
          before_save :get_session_information, :if => :update_sessions?
          after_save :maintain_sessions!, :if => :update_sessions?
      
          # Attributes
          attr_writer "confirm_#{options[:password_field]}"
          attr_accessor "tried_to_set_#{options[:password_field]}"
      
          # Class methods
          class_eval <<-"end_eval", __FILE__, __LINE__
            def self.unique_token
              # Force using the Sha512 because all that we are doing is creating a unique token, a hash is perfect for this
              Authlogic::Sha512CryptoProvider.encrypt(Time.now.to_s + (1..10).collect{ rand.to_s }.join)
            end
        
            def self.crypto_provider
              #{options[:crypto_provider]}
            end
        
            def self.forget_all!
              # Paginate these to save on memory
              records = nil
              i = 0
              begin
                records = find(:all, :limit => 50, :offset => i)
                records.each { |record| record.forget! }
                i += 50
              end while !records.blank?
            end
          end_eval
      
          # Instance methods
          if column_names.include?("last_request_at")
            class_eval <<-"end_eval", __FILE__, __LINE__
              def logged_in?
                !last_request_at.nil? && last_request_at > #{options[:logged_in_timeout].to_i}.seconds.ago
              end
            end_eval
          end
      
          class_eval <<-"end_eval", __FILE__, __LINE__
            def #{options[:password_field]}=(pass)
              return if pass.blank?
              self.tried_to_set_#{options[:password_field]} = true
              @#{options[:password_field]} = pass
              self.#{options[:remember_token_field]} = self.class.unique_token
              self.#{options[:password_salt_field]} = self.class.unique_token
              self.#{options[:crypted_password_field]} = crypto_provider.encrypt(@#{options[:password_field]} + #{options[:password_salt_field]})
            end
        
            def valid_#{options[:password_field]}?(attempted_password)
              return false if attempted_password.blank? || #{options[:crypted_password_field]}.blank? || #{options[:password_salt_field]}.blank?
              attempted_password == #{options[:crypted_password_field]} ||
                (crypto_provider.respond_to?(:decrypt) && crypto_provider.decrypt(#{options[:crypted_password_field]}) == attempted_password + #{options[:password_salt_field]}) ||
                (!crypto_provider.respond_to?(:decrypt) && crypto_provider.encrypt(attempted_password + #{options[:password_salt_field]}) == #{options[:crypted_password_field]})
            end
          end_eval
      
          class_eval <<-"end_eval", __FILE__, __LINE__
            def #{options[:password_field]}; end
            def confirm_#{options[:password_field]}; end
        
            def crypto_provider
              self.class.crypto_provider
            end
        
            def forget!
              self.#{options[:remember_token_field]} = self.class.unique_token
              save_without_session_maintenance(false)
            end
        
            def reset_#{options[:password_field]}!
              chars = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a
              newpass = ""
              1.upto(10) { |i| newpass << chars[rand(chars.size-1)] }
              self.#{options[:password_field]} = newpass
              self.confirm_#{options[:password_field]} = newpass
              save_without_session_maintenance(false)
            end
            alias_method :randomize_password!, :reset_password!
        
            def save_without_session_maintenance(*args)
              @skip_session_maintenance = true
              result = save(*args)
              @skip_session_maintenance = false
              result
            end
        
            protected
              def update_sessions?
                !@skip_session_maintenance && #{options[:session_class]}.activated? && !#{options[:session_ids].inspect}.blank? && #{options[:remember_token_field]}_changed?
              end
          
              def get_session_information
                # Need to determine if we are completely logged out, or logged in as another user
                @_sessions = []
                @_logged_out = true
            
                #{options[:session_ids].inspect}.each do |session_id|
                  session = #{options[:session_class]}.find(*[session_id].compact)
                  if session
                    if !session.record.blank?
                      @_logged_out = false
                      @_sessions << session if session.record == self
                    end
                  end
                end
              end
          
              def maintain_sessions!
                if @_logged_out
                  create_session!
                elsif !@_sessions.blank?
                  update_sessions!
                end
              end
          
              def create_session!
                # We only want to automatically login into the first session, since this is the main session. The other sessions are sessions
                # that need to be created after logging into the main session.
                session_id = #{options[:session_ids].inspect}.first
            
                # If we are already logged in, ignore this completely. All that we care about is updating ourself.
                next if #{options[:session_class]}.find(*[session_id].compact)
                          
                # Log me in
                args = [self, session_id].compact
                #{options[:session_class]}.create(*args)
              end
          
              def update_sessions!
                # We found sessions above, let's update them with the new info
                @_sessions.each do |stale_session|
                  stale_session.unauthorized_record = self
                  stale_session.save
                end
              end
          
              def tried_to_set_password?
                tried_to_set_password == true
              end
          
              def validate_password
                if new_record? || tried_to_set_#{options[:password_field]}?
                  if @#{options[:password_field]}.blank?
                    errors.add(:#{options[:password_field]}, "can not be blank")
                  else
                    errors.add(:confirm_#{options[:password_field]}, "did not match") if @confirm_#{options[:password_field]} != @#{options[:password_field]}
                  end
                end
              end
          end_eval
        end
      end
    end
  end
end

ActiveRecord::Base.extend Authlogic::ORMAdapters::ActiveRecordAdapter::ActsAsAuthentic