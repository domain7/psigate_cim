#  This class implements the Psigate Account Manager gateway for the ActiveMerchant module.
#  Psigate = http://www.psigate.com/ The class  is currently set up to use
#  the psigate test server while rails is in testing or developement mode.
#  The real server will be used while in production mode.
#
#  Modifications by Sean O'Hara ( sohara at sohara dot com )
#
#  Usage for a create account and immediate charge is as follows:
#
# @items = [
#   { :ProductID => 'PRODCODE', :Description => 'This is a test1', :Quantity => 1, :Price => 19.99, :Tax1 => 1.99, :Tax2 => 1.09 },
#   { :ProductID => 'CODE1234', :Description => 'This is a test2', :Quantity => 1, :Price => 29.99, :Tax1 => 1.99, :Tax2 => 1.09 }
# ]
# @card = ActiveMerchant::Billing::CreditCard.new( { :type => "visa",   :number => "4005550000000019", :verification_value => "123", :month => 1, :year => Time.now.year+1, :first_name => "John", :last_name => "Smith"} )
# @account = { :Name => 'John Smith', :Company => 'PSiGate Inc.', :Address1 => '145 King St.', :Address2 => '2300', :City => 'Vancouver', :Province => 'British Columbia', :Postalcode => 'V1M 1V1', :Country => 'Canada', :Phone => '555-555-5555', :Fax => '555-555-5555', :Email => 'test@example.com', :Comments => 'No Comment Today' },
#
# @gateway = ActiveMerchant::Billing::PsigateCimGateway.new( :CID => '1000001', :UserID => 'teststore', :Password => 'testpass' )
#
# request = @gateway.request(:action => :account_new, :account => @account, :cards =>  [@card ] )
#
# @accountid =  rs.params['Account'][:AccountID]
#
# response = @gateway.request(:action => :charge_now, :charge => { :RBName => 'Immediate Payment', :StoreID => 'teststore', :AccountID => "#{@accountid}", :SerialNo => 1 }, :items => [ @items[0], @items[1] ] )
require 'rexml/document'
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PsigateCimGateway < Gateway
      TEST_URL = 'https://dev.psigate.com:8645/Messenger/AMMessenger'
      LIVE_URL = 'https://secure.psigate.com:10921/Messenger/AMMessenger'

      self.supported_cardtypes = [:visa, :master, :american_express]
      self.supported_countries = ['CA']
      self.homepage_url = 'http://www.psigate.com/'
      self.display_name = 'PsigateCIM'

      def initialize( options = {} )
        requires!( options, :CID, :UserID, :Password )
        @options = options
        @account_actions = {
          :account_summary          => 'AMA00',
          :account_new              => 'AMA01',
          :account_update           => 'AMA02',
          :account_detail           => 'AMA05',
          :account_enable           => 'AMA08',
          :account_disable          => 'AMA09',
          :account_card_new         => 'AMA11',
          :account_card_delete      => 'AMA14',
          :account_card_enable      => 'AMA18',
          :account_card_disable     => 'AMA19',
        }
        @charge_actions = {
          :charge_summary           => 'RBC00',
          :charge_new               => 'RBC01',
          :charge_update            => 'RBC02',
          :charge_delete            => 'RBC04',
          :charge_detail            => 'RBC05',
          :charge_enable            => 'RBC08',
          :charge_disable           => 'RBC09',
          :charge_item_new          => 'RBC11',
          :charge_item_delete       => 'RBC14',
          :charge_item_enable       => 'RBC18',
          :charge_item_disable      => 'RBC19',
          :charge_now               => 'RBC99',
        }
        @invoice_actions = {
          :invoice_summary          => 'INV00',
          :invoice_update           => 'INV02',
          :invoice_detail           => 'INV05',
          :invoice_mark_paid        => 'INV08',
          :invoice_mark_outstanding => 'INV09',
          :invoice_rebill           => 'INV99',
        }
        @template_actions = {
          :template_summary         => 'CTL00',
          :template_new             => 'CTL01',
          :template_update          => 'CTL02',
          :template_delete          => 'CTL04',
          :template_detail          => 'CTL05',
          :template_enable          => 'CTL08',
          :template_disable         => 'CTL09',
          :template_item_new        => 'CTL11',
          :template_item_delete     => 'CTL14',
          :template_item_enable     => 'CTL18',
          :template_item_disable    => 'CTL19',
        }
        @report_actions = {
          :report_summary           => 'EMR00',
          :report_new               => 'EMR01',
          :report_update            => 'EMR02',
          :report_delete            => 'EMR04',
          :report_detail            => 'EMR05',
          :report_enable            => 'EMR08',
          :report_disable           => 'EMR09'
        }
        @actions = @account_actions.merge( @charge_actions ).merge( @invoice_actions ).merge( @template_actions ).merge( @report_actions )
        @item_fields = [ :ProductID, :Description, :Quantity, :Price, :Tax1, :Tax2, :Cost, :ItemSerialNo ]
        @card_fields = [ :SerialNo, :CardHolder, :CardNumber, :CardExpMonth, :CardExpYear ]
        @paymethod_fields = [ :AccountID, :SerialNo ]
        @report_fields = [ :Type, :Interval, :Period, :Address, :Status ]
        @account_fields = [ :AccountID, :SerialNo, :Name, :Company, :Address1, :Address2, :City, :Province, :Postalcode, :Country, :Phone, :Fax, :Email, :Comments ]
        @charge_fields = [ :RBCID, :AccountID, :RBName, :StoreID, :ItemSerialNo, :SerialNo, :Interval, :RBTrigger, :ProcessType, :Status, :StartTime, :EndTime ]
        @invoice_fields = [ :AccountID, :InvoiceNo, :PayerName, :DateFrom, :DateTo, :SubNo, :Status ]
        super
      end

      def request( args )
        requires!( args, :action )
        if @actions.include?( args[:action] )
          xml = REXML::Document.new
          xml << REXML::XMLDecl.new
          root = request_params( args[:action] )
          xml.add_element( nodes = send( args[:action], args, root ) )
          commit( xml.to_s )
        end
      end

      private

      def commit( xml )
        response = parse( ssl_post( test? ? TEST_URL : LIVE_URL, xml ) )
        Response.new( response[:success], response[:message], response, :test => test?, :authorization => response[:authorization])
      end

      def text_nodes( node )
        if node.nil?
          return nil
        elsif node.has_elements?
          out = {}
          node.each_element do |n|
            out.merge!( text_nodes( n ) ){ |key, v1, v2| v1.kind_of?( Array ) ? ( v1 + [v2] ) : ( [v1, v2] ) }
          end
          {node.name.to_sym => out}
        else
          {node.name.to_sym => normalize( node.text ) }
        end
      end

      def parse( xml )
        xml = REXML::Document.new( xml )
        response = text_nodes( xml.root )[:Response]
        response[:message] = response[:ReturnMessage] ? response[:ReturnMessage] : 'Global Error Receipt'
        response[:success] = !!( response[:message] =~ /successfully/i )
        response[:complete] = !( response[:ReturnMessage].nil? )
        response[:authorization] = ( response[:Invoice] && response[:Invoice][:InvoiceNo] ) ? response[:Invoice][:InvoiceNo] : nil
        response
      end

      def normalize(field)
        case field
        when "true"   then true
        when "false"  then false
        when ""       then nil
        when "null"   then nil
        else field
        end
      end

      def am_card_to_psi (card_array)
        c_array =[]
        card_array.each do |card|
          if card.class.to_s == "ActiveMerchant::Billing::CreditCard"
            c_array << {
              :CardHolder => [card.first_name, card.last_name].compact.join(' '),
              :CardNumber => card.number,
              :CardExpMonth => "%02d" % card.month,
              :CardExpYear => card.year.to_s[2..3]
            }
          end
        end
        c_array
      end

      def request_params( action )
        root = REXML::Document.new.add_element( 'Request' )
        for key, value in @options
          root.add_element( key.to_s ).text = value if value
        end
        root.add_element( 'Action' ).text = @actions[action] if @actions.include?( action )
        return root
      end

      def build_params( root_node = 'Condition', valid_fields = [], options = {} )
        root = REXML::Document.new.add_element( root_node )
        valid_fields.each do |field|
          root.add_element( field.to_s ).text = options[field] if options[field]
        end
        root
      end

      def build_nested_params( root_node = 'Condition', valid_fields = [], options = {}, nested_node = 'CardInfo', nested_fields = [], nested_options = [] )
        root = build_params( root_node, valid_fields, options )
        nested_options.each do |nested|
          root.add_element(build_params( nested_node, nested_fields, nested))
        end
        root
      end

      def account_summary( args, root )
        requires!( args, :conditions )
        root.add_element(build_params( 'Condition', @account_fields, args[:conditions]))
        return root
      end
      def account_new( args, root )
        requires!( args, :account, :cards )
        card_array = am_card_to_psi( args[:cards] )
        root.add_element(build_nested_params( 'Account', @account_fields, args[:account], 'CardInfo', @card_fields, card_array))
        return root
      end
      def account_update( args, root )
        requires!( args, :conditions, :account )
        root.add_element(build_params( 'Condition', @account_fields, args[:conditions]))
        root.add_element(build_params( 'Update', @account_fields, args[:account]))
        return root
      end
      def account_detail( args, root )
        requires!( args, :conditions )
        root.add_element(build_params( 'Condition', @account_fields, args[:conditions]))
        return root
      end
      def account_enable( args, root )
        requires!( args, :conditions )
        root.add_element(build_params( 'Condition', @account_fields, args[:conditions]))
        return root
      end
      def account_disable( args, root )
        requires!( args, :conditions )
        root.add_element(build_params( 'Condition', @account_fields, args[:conditions]))
        return root
      end
      def account_card_new( args, root )
        card_array = am_card_to_psi( args[:cards] )
        requires!( args, :account, :cards )
        root.add_element(build_nested_params( 'Account', @account_fields, args[:account], 'CardInfo', @card_fields, card_array))
        return root
      end
      def account_card_delete( args, root )
        requires!( args, :conditions )
        root.add_element(build_params( 'Condition', @paymethod_fields, args[:conditions]))
        return root
      end
      def account_card_enable( args, root )
        requires!( args, :conditions )
        root.add_element(build_params( 'Condition', @paymethod_fields, args[:conditions]))
        return root
      end
      def account_card_disable( args, root )
        requires!( args, :conditions )
        root.add_element(build_params( 'Condition', @paymethod_fields, args[:conditions]))
        return root
      end
      def charge_summary( args, root )
        requires!( args, :conditions )
        root.add_element(build_params( 'Condition', @charge_fields, args[:conditions]))
        puts root.to_s
        return root
      end
      def charge_new( args, root )
        requires!( args, :charge, :items )
        root.add_element(build_nested_params( 'Charge', @charge_fields, args[:charge], 'ItemInfo', @item_fields, args[:items]))
        return root
      end
      def charge_update( args, root )
        requires!( args, :conditions, :charge )
        root.add_element(build_params( 'Condition', @charge_fields, args[:conditions]))
        root.add_element(build_params( 'Update', @charge_fields, args[:charge]))
        return root
      end
      def charge_delete( args, root )
        requires!( args, :conditions )
        root.add_element(build_params( 'Condition', @charge_fields, args[:conditions]))
        return root
      end
      def charge_detail( args, root )
        requires!( args, :conditions )
        root.add_element(build_params( 'Condition', @charge_fields, args[:conditions]))
        return root
      end
      def charge_enable( args, root )
        requires!( args, :conditions )
        root.add_element(build_params( 'Condition', @charge_fields, args[:conditions]))
        return root
      end
      def charge_disable( args, root )
        requires!( args, :conditions )
        root.add_element(build_params( 'Condition', @charge_fields, args[:conditions]))
        return root
      end
      def charge_item_new( args, root )
        requires!( args, :charge, :items )
        root.add_element(build_nested_params( 'Charge', @charge_fields, args[:charge], 'ItemInfo', @item_fields, args[:items]))
        return root
      end
      def charge_item_delete( args, root )
        requires!( args, :conditions )
        root.add_element(build_params( 'Condition', @charge_fields, args[:conditions]))
        return root
      end
      def charge_item_enable( args, root )
        requires!( args, :conditions )
        root.add_element(build_params( 'Condition', @charge_fields, args[:conditions]))
        return root
      end
      def charge_item_disable( args, root )
        requires!( args, :conditions )
        root.add_element(build_params( 'Condition', @charge_fields, args[:conditions]))
        return root
      end
      def charge_now( args, root )
        requires!( args, :charge, :items )
        root.add_element(build_nested_params( 'Charge', @charge_fields, args[:charge], 'ItemInfo', @item_fields, args[:items]))
        return root
      end
      def template_summary( args, root )
        requires!( args, :conditions )
        root.add_element(build_params( 'Condition', @charge_fields, args[:conditions]))
        return root
      end
      def template_new( args, root )
        requires!( args, :template, :items )
        root.add_element(build_nested_params( 'ChargeTemplate', @charge_fields, args[:template], 'ItemInfo', @item_fields, args[:items]))
        return root
      end
      def template_update( args, root )
        requires!( args, :conditions, :template )
        root.add_element(build_params( 'Condition', @charge_fields, args[:conditions]))
        root.add_element(build_params( 'Update', @charge_fields, args[:template]))
        return root
      end
      def template_delete( args, root )
        requires!( args, :conditions )
        root.add_element(build_params( 'Condition', @charge_fields, args[:conditions]))
        return root
      end
      def template_detail( args, root )
        requires!( args, :conditions )
        root.add_element(build_params( 'Condition', @charge_fields, args[:conditions]))
        return root
      end
      def template_enable( args, root )
        requires!( args, :conditions )
        root.add_element(build_params( 'Condition', @charge_fields, args[:conditions]))
        return root
      end
      def template_disable( args, root )
        requires!( args, :conditions )
        root.add_element(build_params( 'Condition', @charge_fields, args[:conditions]))
        return root
      end
      def template_item_new( args, root )
        requires!( args, :template, :items )
        root.add_element(build_nested_params( 'ChargeTemplate', @charge_fields, args[:template], 'ItemInfo', @item_fields, args[:items]))
        return root
      end
      def template_item_delete( args, root )
        requires!( args, :conditions )
        root.add_element(build_params( 'Condition', @charge_fields, args[:conditions]))
        return root
      end
      def template_item_enable( args, root )
        requires!( args, :conditions )
        root.add_element(build_params( 'Condition', @charge_fields, args[:conditions]))
        return root
      end
      def template_item_disable( args, root )
        requires!( args, :conditions )
        root.add_element(build_params( 'Condition', @charge_fields, args[:conditions]))
        return root
      end
      def invoice_summary( args, root )
        requires!( args, :conditions )
        root.add_element(build_params( 'Condition', @invoice_fields, args[:conditions]))
        return root
      end
      def invoice_update( args, root )
        requires!( args, :conditions, :invoice )
        root.add_element(build_params( 'Condition', @invoice_fields, args[:conditions]))
        root.add_element(build_params( 'Update', @invoice_fields, args[:invoice]))
        return root
      end
      def invoice_detail( args, root )
        requires!( args, :conditions )
        root.add_element(build_params( 'Condition', @invoice_fields, args[:conditions]))
        return root
      end
      def invoice_mark_paid( args, root )
        requires!( args, :conditions )
        root.add_element(build_params( 'Condition', @invoice_fields, args[:conditions]))
        return root
      end
      def invoice_mark_outstanding( args, root )
        requires!( args, :conditions )
        root.add_element(build_params( 'Condition', @invoice_fields, args[:conditions]))
        return root
      end
      def invoice_rebill( args, root )
        requires!( args, :conditions )
        root.add_element(build_params( 'Condition', @invoice_fields, args[:conditions]))
        return root
      end
      def report_summary( args, root )
        requires!( args, :conditions )
        root.add_element(build_params( 'Condition', @report_fields, args[:conditions]))
        return root
      end
      def report_new( args, root )
        requires!( args, :report )
        root.add_element(build_params( 'EmailReportSetting', @report_fields, args[:report]))
        return root
      end
      def report_update( args, root )
        requires!( args, :conditions, :report )
        root.add_element(build_params( 'Condition', @report_fields, args[:conditions]))
        root.add_element(build_params( 'Update', @report_fields, args[:report]))
        return root
      end
      def report_delete( args, root )
        requires!( args, :conditions )
        root.add_element(build_params( 'Condition', @report_fields, args[:conditions]))
        return root
      end
      def report_detail( args, root )
        requires!( args, :conditions )
        root.add_element(build_params( 'Condition', @report_fields, args[:conditions]))
        return root
      end
      def report_enable( args, root )
        requires!( args, :conditions )
        root.add_element(build_params( 'Condition', @report_fields, args[:conditions]))
        return root
      end
      def report_disable( args, root )
        requires!( args, :conditions )
        root.add_element(build_params( 'Condition', @report_fields, args[:conditions]))
        return root
      end
    end
  end
end
