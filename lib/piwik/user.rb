module Piwik
  class User < Piwik::Base
    attr_accessor :login, :password, :email, :user_alias
    attr_reader :created_at, :config
    
    # Initializes a new <tt>Piwik::User</tt> object, with the supplied attributes. 
    # 
    # You can pass the URL for your Piwik install and an authorization token as 
    # the second and third parameters. If you don't, than it will try to find 
    # them in a <tt>'~/.piwik'</tt> or <tt>RAILS_ROOT/config/piwik.yml</tt> 
    # (and create the file with an empty template if it doesn't exists).
    # 
    # Valid (and required) attributes are:
    # * <tt>:login</tt> - the user login
    # * <tt>:password</tt> - the user password
    # * <tt>:email</tt> - the user email
    # * <tt>:alias</tt> - the user alias
    def initialize(attributes={}, piwik_url=nil, auth_token=nil)
      raise ArgumentError, "expected an attributes Hash, got #{attributes.inspect}" unless attributes.is_a?(Hash)
      @config = if piwik_url.nil? || auth_token.nil?
        self.class.load_config_from_file
      else
        {:piwik_url => piwik_url, :auth_token => auth_token}
      end
      load_attributes(attributes)
    end
    
    # Returns <tt>true</tt> if the current site does not exists in the Piwik yet.
    def new?
      created_at.nil? or created_at.blank?
    end
    
    # Saves the current user in Piwik.
    # 
    # Calls <tt>create</tt> it it's a new user, <tt>update</tt> otherwise.
    def save
      new? ? create : update
    end
    
    # Saves the current new user in Piwik.
    # 
    # Equivalent Piwik API call: UsersManager.addUser (userLogin, password, email, alias)
    def create
      raise ArgumentError, "User already exists in Piwik, call 'update' instead" unless new?
      raise ArgumentError, "Login can not be blank" if login.blank?
      raise ArgumentError, "Password can not be blank" if password.blank?
      raise ArgumentError, "Email can not be blank" if email.blank?
      user_alias = login if user_alias.blank?
      
      xml = call('UsersManager.addUser', :userLogin => login, :password => password, :email => email, :alias => user_alias)
      result = parse_xml(xml)
      @created_at = Time.current
      if result["success"]
        result["success"]["message"] == "ok" ? true : false
      else
        false
      end
    end
    
    # Saves the current user in Piwik, updating it's data.
    # 
    # Equivalent Piwik API call: UsersManager.updateUser (userLogin, password, email, alias)
    def update
      raise UnknownUser, "User not existent in Piwik yet, call 'save' first" if new?
      raise ArgumentError, "Login can not be blank" if login.blank?
      raise ArgumentError, "Password can not be blank" if password.blank?
      raise ArgumentError, "Email can not be blank" if email.blank?
      user_alias = login if user_alias.blank?
      
      xml = call('UsersManager.updateUser', :userLogin => login, :password => password, :email => email, :alias => user_alias)
      result = parse_xml(xml)
      result['success'] ? true : false
    end
    
    # Deletes the current user from Piwik.
    # 
    # Equivalent Piwik API call: UsersManager.deleteUser (userLogin)
    def destroy
      raise UnknownUser, "User not existent in Piwik yet, call 'save' first" if new?
      xml = call('UsersManager.deleteUser', :userLogin => login)
      result = parse_xml(xml)
      freeze
      result['success'] ? true : false
    end
    
    # Returns an instance of <tt>Piwik::User</tt> representing the user identified by 
    # the supplied <tt>userLogin</tt>. Raises a <tt>Piwik::ApiError</tt> if the user doesn't 
    # exists or if the user associated with the supplied auth_token does not 
    # have 'admin' access.
    # 
    # You can pass the URL for your Piwik install and an authorization token as 
    # the second and third parameters. If you don't, than it will try to find 
    # them in a <tt>'~/.piwik'</tt> or <tt>RAILS_ROOT/config/piwik.yml</tt> 
    # (and create the file with an empty template if it doesn't exists).
    def self.load(user_login, piwik_url=nil, auth_token=nil)
      raise ArgumentError, "expected a user Login" if user_login.nil?
      @config = if piwik_url.nil? || auth_token.nil?
        load_config_from_file
      else
        {:piwik_url => piwik_url, :auth_token => auth_token}
      end
      attributes = get_user_attributes_by_login(user_login, @config[:piwik_url], @config[:auth_token])
      new(attributes, @config[:piwik_url], @config[:auth_token])
    end
    
  private
    # Loads the attributes in the instance variables.
    def load_attributes(attributes)
      @login = attributes[:login]
      @password = attributes[:password]
      @email = attributes[:email]
      @user_alias = attributes[:user_alias]
      @created_at = attributes[:created_at]
    end
    
    # Returns a hash with the attributes of the supplied user, identified 
    # by it's Login in <tt>user_login</tt>.
    # 
    # Equivalent Piwik API call: UsersManager.getUser (userLogin)
    def self.get_user_attributes_by_login(user_login, piwik_url, auth_token)
      xml = call('UsersManager.getUser', {:userLogin => user_login}, piwik_url, auth_token)
      result = parse_xml(xml)
      attributes = {
        :login => result['row']['login'],
        :user_alias => result['row']['alias'],
        :email => result['row']['email'],
        :password => result['row']['password'],
        :created_at => Time.parse(result['row']['date_registered'])
      }
      attributes
    end
  end
end
