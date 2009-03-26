# ActsAsTouchable
module ActiveRecord #:nodoc:
  
  module Acts #:nodoc: 
    module Touchable #:nodoc:
      
      def self.included(base) 
        base.extend(ClassMethods)                                
      end 
      
      module ClassMethods 
        def acts_as_touchable options ={}
          column = options.delete(:column)
          touch_dirty = options.delete(:touch_dirty) 
          if column.nil? && self.column_names.grep(/^(updated_(at|on))$/i)
            column =  $1
          else raise ActiveRecord::Acts::Touchable::Untouchable, "Acts As Touchable requires a touchable model to have an updated_on or an updated_at column. #{@class} has neither of these columns. You may also specify a column with the :column option for acts_as_touchable" 
          end #unless
          
          if self.columns_hash[column.to_s]
            unless [:datetime, :timestamp].include?(self.columns_hash[column.to_s].type)
              raise ActiveRecord::ActiveRecordError, "Acts As Touchable Error: Expected column #{column} to be of datetime or timestamp type, not #{columns_hash[column.to_s].type}."
            end                                                
          else
            raise ActiveRecord::ActiveRecordError, "Acts As Touchable Error: Column #{column} does not exist on table #{self.table_name}."
          end
          
          
          
          class_eval %{
            def touch
              
              if changed? #{"|| true" if touch_dirty}
                raise ActiveRecord::Acts::Touchable::ModifiedError, "Touch aborted: Tried touching dirty record"
              end
              
              
                self[#{column}]= DateTime.now
              return save
                  
                  
                
            end
            
            
            def touch!              
              if changed? #{"|| true" if touch_dirty}
                raise ActiveRecord::Acts::Touchable::ModifiedError, "Touch aborted: Tried touching dirty record"
              end
              
                self[#{column}]= DateTime.now
                save!
            end          
          }
          
          
          
        end                                                                
      end
      
      
      module AssociationClassMethods                                                                 
        
        def self.extended(klass)
          [:before, :after].each do |at|
            
            [:validation,:create, :save,:destroy, :update].each do |stage|
              class_eval %{
              
              def #{klass}.touch_#{at}_#{stage}(*args)
                args.each do |arg|
                  
                  arg_reflections = #{klass}.reflections[arg.to_sym]
                  if arg_reflections.options[:touchable] && Kernel::const_get(arg_reflections.class_name).instance_methods.include?("touch")
                    self.send "#{at}_#{stage}", "touch_\#{arg}"
                  else
                    raise ActiveRecord::Acts::Touchable::UntouchableError, "\#{arg_reflections.class_name} is not touchable."
                  end
                  
                end # each 
              end  #def                                                                                           
              }
              
              if stage == :validation 
                [:create,:update].each do |on_action|
                  class_eval %{
                  
                    def #{klass}.touch_#{at}_#{stage}_on_#{on_action}(*args)                                                   
                      args.each do |arg|
                        arg_reflections = #{klass}.reflections[arg.to_sym]
                      if arg_reflections.options[:touchable] && Kernel::const_get(arg_reflections.class_name).instance_methods.include?("touch")
                        self.send "#{at}_#{stage}_on_#{on_action}", "touch_\#{arg}"
                      else
                        raise ActiveRecord::Acts::Touchable::UntouchableError, "\#{arg_reflections.class_name} is not touchable."
                      end
                       end
                   end                                                                                                
                   } 
                end #on_action
              end #if
              
            end #stage
            end#at            
          end #generate class methods 
          
          
          
          
        end #AssociationClassMethods
        
        module AssociationInstanceMethods
          
        end
        
        class UntouchableError < Exception                                                                                                                                                                
        end # class Untouchable
        
        class ModifiedError < Exception
        end
        
        
      end # module Touchable
    end # module Acts
    
    module Associations::ClassMethods
      
      [:belongs_to, :has_one, :has_many].each do |method|
        class_eval %{
                def create_#{method}_reflection_with_touchable(association_id, options)                       
                        
                        touchable =  options.delete(:touchable)                        
                        reflection = create_#{method}_reflection_without_touchable(association_id, options)                                                
                        if touchable
                                reflection.options[:touchable] ||= true                                
                                generate_toucher_instance_methods(association_id, "#{method}")
                                unless touchable == true                                
                                  add_default_callback(touchable, association_id)
                                else
                                  extend ActiveRecord::Acts::Touchable::AssociationClassMethods unless is_a?(ActiveRecord::Acts::Touchable::AssociationClassMethods)
                                end
                                
                        end                                                                        
                        reflection
                end
                alias_method_chain :create_#{method}_reflection, :touchable
                }
      end
      
      protected
      def generate_toucher_instance_methods(association_id, method)
        class_eval %{
          
           if Kernel::const_get("#{association_id.to_s.singularize.camelcase}").instance_methods.include?("touch")
            
            def touch_#{association_id}
              this_stack=  Kernel.caller
              if this_stack.any?{|stack| /save!/ === stack}
                  #{association_id}.#{method == :has_many.to_s ? "all {|association| association.touch!}" : "touch!"}
              elsif this_stack.any?{|stack| /save/ === stack}
                 begin
                  #{association_id}.#{method == :has_many.to_s ? "all {|association| association.touch!}" : "touch!"}
                 rescue StandardError => message
                   errors.add(#{association_id}, message)
                   raise ActiveRecord::Rollback, false
                  end
               end               
             end
             
              def touch_#{association_id}!
                return #{association_id}.#{method == :has_many.to_s ? "all? {|association| association.touch!}" : "touch!"}
              end
          else
            raise ActiveRecord::Acts::Touchable::UntouchableError, "\#{association_id.to_s.singularize.camelcase} is not touchable."                  
           end
        }
        end
        
        def add_default_callback(touchable,association_id)
          unless touchable.to_s =~ /(before|after)_(create|update|save|destroy|validation(_on_create|_on_update)?)/
            raise ActiveRecord::Callbacks::UnknownCallbackError, "#{touchable} is not a valid ActiveRecord::Callback."
          end
          puts association_id
          arg_reflections = self.reflections[association_id.to_sym]
          if arg_reflections.options[:touchable] && Kernel::const_get(arg_reflections.class_name).instance_methods.include?("touch")            
            self.send "#{touchable}", "touch_#{association_id}"
          else
            raise ActiveRecord::Acts::Touchable::UntouchableError, "\#{arg_reflections.class_name} is not touchable."
          end
        end
      
      
    end
  end #module ActiveRecord
