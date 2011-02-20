require 'test_helper'

class RequestProcessorTest < ActiveSupport::TestCase
  include Apotomo::TestCaseMethods::TestController
  
  def root_mum_and_kid!
    mum_and_kid!
    
    @root = Apotomo::Widget.new(parent_controller, 'root', :display)
    @root << @mum
  end
  
  
  context "#root" do
    should "allow external modification of the tree" do
      @processor = Apotomo::RequestProcessor.new(parent_controller)
      root = @processor.root
      root << mouse_mock
      assert_equal 2, @processor.root.size
    end
  end
  
  context "#attach_stateless_blocks_for" do
    setup do
      @processor  = Apotomo::RequestProcessor.new(parent_controller)
      @root       = @processor.root
      assert_equal @root.size, 1
    end
    
    should "allow has_widgets blocks with root parameter" do
      @processor.send(:attach_stateless_blocks_for, [Proc.new{ |root|
        root << widget(:mouse_widget, 'mouse') 
      }], @root, parent_controller)
      
      assert_equal 'mouse', @processor.root['mouse'].name
    end
  end
    
  context "option processing at construction time" do
    context "with empty options" do
      setup do
        @processor = Apotomo::RequestProcessor.new(parent_controller)
      end
      
      should "provide a single root-node for #root" do
        assert_equal 1, @processor.root.size
      end
    end
    
    context "with controller" do
      should "attach the passed parent_controller to root" do
        assert_equal parent_controller, Apotomo::RequestProcessor.new(parent_controller, {}, []).root.parent_controller
      end
    end
  end
  
  
  context "#process_for" do
    setup do
      class KidWidget < Apotomo::Widget
        responds_to_event :doorSlam, :with => :flight
        responds_to_event :doorSlam, :with => :squeak
        def flight; render :text => "away from here!"; end
        def squeak; render :text => "squeak!"; end
      end
  
      procs = [Proc.new{ |root,controller| 
        root << widget(:mouse_widget, 'mum') << KidWidget.new(parent_controller, 'kid', :squeak)
      }]
    
      @processor = Apotomo::RequestProcessor.new(parent_controller, {:js_framework => :prototype}, procs)
    end
    
    should "return an empty array if nothing was triggered" do
      assert_equal [], @processor.process_for({:type => :mouseClick, :source => 'kid'})
    end
    
    should "return 2 page updates when @kid squeaks" do
      assert_equal ["away from here!", "squeak!"], @processor.process_for({:type => :doorSlam, :source => 'kid'})
    end
    
    should "append the params hash to the triggered event" do
      KidWidget.class_eval do
        def squeak(evt); render :text => evt.data.inspect; end
      end
      
      assert_equal ["away from here!", "{:type=>:doorSlam, :source=>\"kid\"}"], @processor.process_for({:type => :doorSlam, :source => 'kid'})
    end
    
    should "raise an exception when :source is unknown" do
      assert_raises RuntimeError do
        @processor.process_for({:type => :squeak, :source => 'tom'})
      end
    end
  end
  
  
  context "#render_widget_for" do
    setup do
      MouseWidget.class_eval do
        def squeak; render :text => "squeak!"; end
      end
      
      @processor = Apotomo::RequestProcessor.new(parent_controller, {}, 
        [Proc.new { |root| root << widget(:mouse_widget, 'mum', :squeak, :volume => 9) }])
    end
    
    should "render the widget when passing an existing widget id" do
      assert_equal 'squeak!', @processor.render_widget_for('mum')
    end
    
    should "render the widget when passing an existing widget instance" do
      assert_equal 'squeak!', @processor.render_widget_for(@processor.root['mum'])
    end
    
    should "raise an exception when a non-existent widget id is passed" do
      assert_raises RuntimeError do
        @processor.render_widget_for('mummy')
      end
    end
    
    should "pass options as state-args" do
      @processor.root['mum'].instance_eval do
        def squeak(pitch)
          @pitch = pitch
        end
      end
      @processor.render_widget_for('mum', :high)
      assert_equal(:high, @processor.root['mum'].instance_variable_get(:@pitch))
    end
  end
  
  context "invoking #address_for" do
    setup do
      @processor = Apotomo::RequestProcessor.new(parent_controller)
    end
    
    should "accept an event :type" do
      assert_equal({:type => :squeak, :source => 'mum'}, @processor.address_for(:type => :squeak, :source => 'mum'))
    end
    
    should "accept arbitrary options" do
      assert_equal({:type => :squeak, :volume => 'loud', :source => 'mum'}, @processor.address_for(:type => :squeak, :volume => 'loud', :source => 'mum'))
    end
    
    should "complain if no type given" do
      assert_raises RuntimeError do
        @processor.address_for(:source => 'mum')
      end
    end
    
    should "complain if no source given" do
      assert_raises RuntimeError do
        @processor.address_for(:type => :footsteps)
      end
    end
  end
end

class RequestProcessorHooksTest < ActiveSupport::TestCase
  include Apotomo::TestCaseMethods::TestController
  include Apotomo::TestCaseMethods
  
  context "Hooks in RequestProcessor" do
    setup do
      @class = Class.new(Apotomo::RequestProcessor)
    end
    
    context ":after_initialize hook" do
      should "be called after the has_widgets blocks invokation" do
        @k = mouse_mock("kid")
        @class.after_initialize do |r|
          r.root["mum"] << @k
        end
        
        @r = @class.new(parent_controller, {}, 
          [Proc.new { |root| root << widget(:mouse_widget, 'mum') }])
        
        assert_equal @r.root["mum"]["kid"], @k
      end
    end
    
    context ":after_fire hook" do
      should "be called in #process_for after fire" do
        @k = mouse_mock("kid")
        @class.after_fire do |r|
          r.root["mum"] << @k = mouse_mock("kid")
        end
        
        # DISCUSS: maybe add a trigger test here?
        @r = @class.new(parent_controller, {}, 
          [Proc.new { |root| root << widget(:mouse_widget, 'mum') }])
        @r.process_for(:source => "root", :type => :noop) # calls ~after_fire.
        
        assert_equal @k, @r.root["mum"]["kid"]
      end
    end
  end
end
