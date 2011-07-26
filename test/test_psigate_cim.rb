require 'activemerchant'
require 'test/unit'

class TestFaker < Test::Unit::TestCase
  def setup
    ActiveMerchant::Billing::Base.mode = :test
    @gateway = ActiveMerchant::Billing::PsigateCimGateway.new( :CID => '1000001', :UserID => 'teststore', :Password => 'testpass' )

    cc = [
    { :type => "visa",   :number => "4005550000000019", :verification_value => "123", :month => 1, :year => Time.now.year+1, :first_name => "John", :last_name => "Smith"},
    { :type => "visa",   :number => "4024007148673576", :verification_value => "123", :month => 1, :year => Time.now.year+1, :first_name => "John", :last_name => "Smith"},
    { :type => 'visa',   :number => '4111111111111111', :verification_value => "123", :month => 1, :year => Time.now.year+1, :first_name => "John", :last_name => "Smith"},
    { :type => 'visa',   :number => '4012000033330026', :verification_value => "123", :month => 1, :year => Time.now.year+1, :first_name => "John", :last_name => "Smith"},
    { :type => 'visa',   :number => '4217651111111119', :verification_value => "123", :month => 1, :year => Time.now.year+1, :first_name => "John", :last_name => "Smith"},
    { :type => 'master', :number => '5454545454545454', :verification_value => "123", :month => 1, :year => Time.now.year+1, :first_name => "John", :last_name => "Smith"},
    { :type => 'master', :number => '5424180279791765', :verification_value => "123", :month => 1, :year => Time.now.year+1, :first_name => "John", :last_name => "Smith"},
    { :type => 'master', :number => '5191111111111111', :verification_value => "123", :month => 1, :year => Time.now.year+1, :first_name => "John", :last_name => "Smith"},
    { :type => 'amex',   :number => '370000000000002',  :verification_value => "123", :month => 1, :year => Time.now.year+1, :first_name => "John", :last_name => "Smith"},
    { :type => 'amex',   :number => '371449635398431',  :verification_value => "123", :month => 1, :year => Time.now.year+1, :first_name => "John", :last_name => "Smith"}
    ]

    @cards = []
    cc.each do |c|
    @cards << ActiveMerchant::Billing::CreditCard.new(c)
    end

    @account = { :Name => 'John Smith', :Company => 'PSiGate Inc.', :Address1 => '145 King St.', :Address2 => '2300', :City => 'Vancouver', :Province => 'British Columbia', :Postalcode => 'V1M 1V1', :Country => 'Canada', :Phone => '555-555-5555', :Fax => '555-555-5555', :Email => 'test@example.com', :Comments => 'No Comment Today' }

    @items = [
    { :ProductID => 'PRODCODE', :Description => 'This is a test1', :Quantity => 1, :Price => 19.99, :Tax1 => 1.99, :Tax2 => 1.09 },
    { :ProductID => 'CODE1234', :Description => 'This is a test2', :Quantity => 1, :Price => 29.99, :Tax1 => 1.99, :Tax2 => 1.09 },
    { :ProductID => 'CODE4321', :Description => 'This is a test3', :Quantity => 1, :Price => 39.99, :Tax1 => 1.99, :Tax2 => 1.09 },
    { :ProductID => 'REFUND01', :Description => 'This is a test4', :Quantity => 1, :Price => -10.00 }
    ]

    ### CREATE SOME DATA TO TEST WITH:
    puts "\ncreating an account"
    rs = @gateway.request(:action => :account_new, :account => @account , :cards => [ @cards[0] ] )
    @accountid =  rs.params['Account'][:AccountID]
    puts "Created new account AccountID:#{@accountid}\n"

    puts "\ncreating a recurring charge"
    rs = @gateway.request(:action => :charge_new, :charge => { :RBName => 'Monthly Payment', :StoreID => 'teststore', :AccountID => "#{@accountid}", :SerialNo => 1, :Interval => 'M', :RBTrigger => '12', :EndTime => '2011.12.31' }, :items => [ @items[0], @items[3] ])
    @rbcid = rs.params['Charge'][:RBCID]
    puts "Created new charge RBCID:#{@rbcid}\n"

    puts "\ncreating an invoice"
    rs = @gateway.request(:action => :charge_now, :charge => { :RBName => 'Immediate Payment', :StoreID => 'teststore', :AccountID => "#{@accountid}", :SerialNo => 1 }, :items => [ @items[0], @items[1] ] )
    @invoiceid = rs.params['Invoice'][:InvoiceNo]
    puts "Created new invoice INVOICEID:#{@invoiceid}\n"
    ### CREATE SOME DATA TO TEST WITH:
  end

  def test_all
    rs = @gateway.request(:action => :account_card_new, :account => { :AccountID => "#{@accountid}" }, :cards => [ @cards[2] ])
    assert_equal(rs.success?, true)
    rs = @gateway.request(:action => :account_update, :conditions => { :AccountID => "#{@accountid}" }, :account => { :Address1 => '1234 Home Street' })
    assert_equal(rs.success?, true)
    rs = @gateway.request(:action => :account_summary, :conditions => { :AccountID => "#{@accountid}" })
    assert_equal(rs.success?, true)
    rs = @gateway.request(:action => :account_detail, :conditions => { :AccountID => "#{@accountid}" })
    assert_equal(rs.success?, true)
    rs = @gateway.request(:action => :account_disable, :conditions => { :AccountID => "#{@accountid}" })
    assert_equal(rs.success?, true)
    rs = @gateway.request(:action => :account_enable, :conditions => { :AccountID => "#{@accountid}" })
    assert_equal(rs.success?, true)
    rs = @gateway.request(:action => :account_card_disable, :conditions => { :AccountID => "#{@accountid}", :SerialNo => 2 })
    assert_equal(rs.success?, true)
    rs = @gateway.request(:action => :account_card_enable, :conditions => { :AccountID => "#{@accountid}", :SerialNo => 2 })
    assert_equal(rs.success?, true)
    rs = @gateway.request(:action => :account_card_delete, :conditions => { :AccountID => "#{@accountid}", :SerialNo => 2 })
    assert_equal(rs.success?, true)
    rs = @gateway.request(:action => :charge_now, :charge => { :RBName => 'Immediate Payment', :StoreID => 'teststore', :AccountID => "#{@accountid}", :SerialNo => 1 }, :items => [ @items[0], @items[1] ] )
    assert_equal(rs.success?, true)
    rs = @gateway.request(:action => :charge_new, :charge => { :RBName => 'Monthly Payment', :StoreID => 'teststore', :AccountID => "#{@accountid}", :SerialNo => 1, :Interval => 'M', :RBTrigger => '12', :EndTime => '2011.12.31' }, :items => [ @items[0], @items[3] ])
    assert_equal(rs.success?, true)
    rs = @gateway.request(:action => :charge_update, :conditions => { :RBCID => "#{@rbcid}" }, :charge => { :RBName => 'New Monthly Payment' })
    assert_equal(rs.success?, true)
    rs = @gateway.request(:action => :charge_detail, :conditions => { :RBCID => "#{@rbcid}" })
    assert_equal(rs.success?, true)
    rs = @gateway.request(:action => :charge_summary, :conditions => { :RBName => 'Monthly Payment', :StoreID => 'teststore', :AccountID => "#{@accountid}", :Interval => 'M', :RBTrigger => '12' })
    assert_equal(rs.success?, true)
    rs = @gateway.request(:action => :charge_disable, :conditions => { :RBCID => "#{@rbcid}" })
    assert_equal(rs.success?, true)
    rs = @gateway.request(:action => :charge_enable, :conditions => { :RBCID => "#{@rbcid}" })
    assert_equal(rs.success?, true)
    rs = @gateway.request(:action => :charge_delete, :conditions => { :RBCID => "#{@rbcid}" })
    assert_equal(rs.success?, true)
    rs = @gateway.request(:action => :charge_item_new, :charge => { :StoreID => 'teststore', :AccountID => "#{@accountid}", :SerialNo => 1, :Interval => 'M', :RBTrigger => '20', :RBCID => "#{@rbcid}" }, :items => [ @items[2] ])
    assert_equal(rs.success?, true)
    rs = @gateway.request(:action => :template_summary, :conditions => { :Interval => 'M'})
    assert_equal(rs.success?, true)
    rs = @gateway.request(:action => :charge_item_disable, :conditions => { :RBCID => "#{@rbcid}", :ItemSerialNo => 2 })
    assert_equal(rs.success?, true)
    rs = @gateway.request(:action => :charge_item_enable, :conditions => { :RBCID => "#{@rbcid}", :ItemSerialNo => 2 })
    assert_equal(rs.success?, true)
    rs = @gateway.request(:action => :charge_item_delete, :conditions => { :RBCID => "#{@rbcid}", :ItemSerialNo => 2 } )
    assert_equal(rs.success?, true)
    rs = @gateway.request(:action => :template_new, :template => { :RBName => 'Charge Template', :StoreID => 'teststore', :AccountID => "#{@accountid}", :SerialNo => 1 }, :items => [ @items[2] ])
    assert_equal(rs.success?, true)
    rs = @gateway.request(:action => :template_update, :conditions => { :RBCID => "#{@rbcid}" }, :template => { :RBName => 'Jane Smith' })
    assert_equal(rs.success?, true)
    rs = @gateway.request(:action => :template_detail, :conditions => { :RBCID => "#{@rbcid}" })
    assert_equal(rs.success?, true)
    rs = @gateway.request(:action => :template_disable, :conditions => { :RBCID => "#{@rbcid}" })
    assert_equal(rs.success?, true)
    rs = @gateway.request(:action => :template_enable, :conditions => { :RBCID => "#{@rbcid}" })
    assert_equal(rs.success?, true)
    rs = @gateway.request(:action => :template_delete, :conditions => { :RBCID => "#{@rbcid}" })
    assert_equal(rs.success?, true)
    rs = @gateway.request(:action => :template_item_new, :template => { :RBCID => "#{@rbcid}" }, :items => [ @items[1] ])
    assert_equal(rs.success?, true)
    rs = @gateway.request(:action => :template_item_disable, :conditions => { :RBCID => "#{@rbcid}", :ItemSerialNo => 1 })
    assert_equal(rs.success?, true)
    rs = @gateway.request(:action => :template_item_enable, :conditions => { :RBCID => "#{@rbcid}", :ItemSerialNo => 1 })
    assert_equal(rs.success?, true)
    rs = @gateway.request(:action => :template_item_delete, :conditions => { :RBCID => "#{@rbcid}", :ItemSerialNo => 2 })
    assert_equal(rs.success?, true)
    rs = @gateway.request(:action => :invoice_summary, :conditions => { :InvoiceNo => "#{@invoiceid}" })
    assert_equal(rs.success?, true)
    rs = @gateway.request(:action => :invoice_update, :conditions => { :InvoiceNo => "#{@invoiceid}" }, :invoice => { :SerialNo => 1 })
    assert_equal(rs.success?, true)
    rs = @gateway.request(:action => :invoice_detail, :conditions => { :InvoiceNo => "#{@invoiceid}" })
    assert_equal(rs.success?, true)
    rs = @gateway.request(:action => :invoice_mark_paid, :conditions => { :InvoiceNo => "#{@invoiceid}" })
    assert_equal(rs.success?, true)
    rs = @gateway.request(:action => :invoice_mark_outstanding, :conditions => { :InvoiceNo => "#{@invoiceid}" })
    assert_equal(rs.success?, true)
    rs = @gateway.request(:action => :invoice_rebill, :conditions => { :InvoiceNo => "#{@invoiceid}" })
    assert_equal(rs.success?, true)
    rs = @gateway.request(:action => :report_new, :report => { :Type => 'C', :Interval => 'O', :Period => 1, :Address => 'test@example.com', :Status => 'A' })
    assert_equal(rs.success?, true)
    rs = @gateway.request(:action => :report_summary, :conditions => { :Type => 'C' })
    assert_equal(rs.success?, true)
    rs = @gateway.request(:action => :report_update, :conditions => { :Type => 'C' }, :report => { :Status => 'N' })
    assert_equal(rs.success?, true)
    rs = @gateway.request(:action => :report_detail, :conditions => { :Type => 'C' })
    assert_equal(rs.success?, true)
    rs = @gateway.request(:action => :report_disable, :conditions => { :Type => 'C' })
    assert_equal(rs.success?, true)
    rs = @gateway.request(:action => :report_enable, :conditions => { :Type => 'C' })
    assert_equal(rs.success?, true)
    rs = @gateway.request(:action => :report_delete, :conditions => { :Type => 'C' })
    assert_equal(rs.success?, true)
  end
end
