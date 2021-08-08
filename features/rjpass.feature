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

  Scenario: Secrets are stored in a git repo

  Scenario: It pushes changes to a git remote

  Scenario: It encrypts to multiple recipients

  Scenario: Different recipients can be set per subtree

  Scenario: I can list secrets
