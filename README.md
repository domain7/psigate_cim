# Psigate CIM

A Ruby extention to activemerchant (=> 1.15) for the Psigate Account Manager API. (http://psigate.com)

Installation from RubyGems

    gem install psigate_cim

## Usage Example

require 'rubygems'
require 'activemerchant'

```ruby
@items = [
  { :ProductID => 'PRODCODE', :Description => 'This is a test1', :Quantity => 1, :Price => 19.99, :Tax1 => 1.99, :Tax2 => 1.09 },
  { :ProductID => 'CODE1234', :Description => 'This is a test2', :Quantity => 1, :Price => 29.99, :Tax1 => 1.99, :Tax2 => 1.09 }
]
@card = ActiveMerchant::Billing::CreditCard.new( { :type => "visa",   :number => "4005550000000019", :verification_value => "123", :month => 1, :year => Time.now.year+1, :first_name => "John", :last_name => "Smith"} )
@account = { :Name => 'John Smith', :Company => 'PSiGate Inc.', :Address1 => '145 King St.', :Address2 => '2300', :City => 'Vancouver', :Province => 'British Columbia', :Postalcode => 'V1M 1V1', :Country => 'Canada', :Phone => '555-555-5555', :Fax => '555-555-5555', :Email => 'test@example.com', :Comments => 'No Comment Today' },

@gateway = ActiveMerchant::Billing::PsigateCimGateway.new( :CID => '1000001', :UserID => 'teststore', :Password => 'testpass' )

request = @gateway.request(:action => :account_new, :account => @account, :cards =>  [@card ] )

@accountid =  rs.params['Account'][:AccountID]

response = @gateway.request(:action => :charge_now, :charge => { :RBName => 'Immediate Payment', :StoreID => 'teststore', :AccountID => "#{@accountid}", :SerialNo => 1 }, :items => [ @items[0], @items[1] ] )
```
