Feature: command-line password management

  Scenario: secrets are encrypted using age
    Given I am using the example password store
    Then "home/ebay.age" plaintext is "horsebattery"

  Scenario: I can create a specified secret
    Given I am using a temporary password store
    When I store a secret for "home/ebay" with content "horsebattery"
    Then "home/ebay.age" plaintext is "horsebattery"

  Scenario: I can create a generated secret
    Given I am using a temporary password store
    When I generate a secret for "home/ebay" with length 20
    Then I see a 20 character string
    And "home/ebay.age" plaintext matches ^[a-zA-Z0-9]{20}$
    When I generate a secret for "home/fastmail" with length 12
    And "home/fastmail.age" plaintext matches ^[a-zA-Z0-9]{12}$

  Scenario: I can view a secret
    Given I am using the example password store
    When I view the secret "home/ebay"
    Then I see the string "horsebattery"

  Scenario: I can list secrets
    Given I am using the example password store
    When I list the secrets
    Then I see the string "work/gmail"
    And I see the string "home/yahoomail"
    And I see the string "home/ebay"	

  Scenario: I can search for a secret
    Given I am using the example password store
    When I search for "mail"
    Then I see the string "work/gmail"
    And I see the string "home/yahoomail"

  Scenario: I can edit a secret
    Given I am using a temporary password store
    When I store a secret for "work/gmail" with content "staple correct"
    When I edit "work/gmail"
    Then the editor opens a temporary file containing "staple correct"

  Scenario Outline: It encrypts to multiple recipients
    Given I am using a temporary password store
    And there are recipient files in different subtrees
    | pathname  | identity |
    | family    | me.key,partner.key,child.key |
    | work      | me.key,work.key |
    | private   | me.key |
    
    When I store a secret for "private/medical" with content "120/70"
    Then I can decrypt it with key "me.key" to "120/70"
    And I cannot decrypt it with key "work.key"

    When I store a secret for "work/report" with content "persevere"
    Then I can decrypt it with key "me.key" to "persevere"
    And I can decrypt it with key "work.key" to "persevere"
    And I cannot decrypt it with key "child.key"

    When I store a secret for "family/holiday" with content "isle of wight"
    Then I can decrypt it with key "me.key" to "isle of wight"
    And I can decrypt it with key "child.key" to "isle of wight"
    And I cannot decrypt it with key "work.key"
    
  Scenario: Secrets are stored in a git repo
    Given I am using a temporary password store
    And the store is version-controlled
    When I store a secret for "home/ebay" with content "horsebattery"
    Then the change to "home/ebay.age" is committed to version control
    

  Scenario: Sensible path to the store
    Given I do not specify a store
    Then the store directory is under XDG_DATA_HOME
    



