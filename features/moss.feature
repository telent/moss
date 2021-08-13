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

  Scenario: it doesn't overwrite secrets without asking
    Given I am using a temporary password store
    When I store a secret for "home/ebay" with content "first"
    Then I cannot store a secret for "home/ebay" with content "second"
    And "home/ebay.age" plaintext is "first"

  Scenario: it overwrites secrets when forced
    Given I am using a temporary password store
    When I store a secret for "home/ebay" with content "first"
    And I force store a secret for "home/ebay" with content "second"
    Then "home/ebay.age" plaintext is "second"

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

  Scenario: I can delete a secret
    Given I am using a temporary password store
    And there is a secret for "home/ebay"
    When I delete the secret for "home/ebay"
    Then "home/ebay.age" does not exist

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

  Scenario: I can do git operations on the store
    Given I am using a temporary password store
    And the store is version-controlled
    When I store a secret for "home/ebay" with content "horsebattery"
    Then I can run git "config --local -l"
    And I see the string "core.bare=false"

  Scenario: Sensible path to the store
    Given I do not specify a store
    Then the store directory is under XDG_DATA_HOME

  Scenario: I can create a new store
    Given I set MOSS_HOME to a unique temporary pathname
    When I create a moss instance with identity "me.key"
    Then the instance store exists
    And the instance identity is "me.key"
    And the store root has .recipients for the identity "me.key"

  Scenario: I can create a new store with an encrypted key
    Given I set MOSS_HOME to a unique temporary pathname
    When I interactively create a moss instance with identity "encrypted.key" and passphrase "hello foo"
    Then the instance store exists
    And the instance identity is "encrypted.key"
    And the store root has recipient "age1qqawnse9rfxjun2xmklk3r2pudlfjx0z4utjuwlmq7t9l60z9e2sap9vc8"

  Scenario: Files in the store are not readable by other users
    Given I set MOSS_HOME to a unique temporary pathname
    When I create a moss instance with identity "me.key"
    When I generate a secret for "home/ebay" with length 20
    Then the store file "home/ebay.age" is readable only by me
    And the store file "home/" is readable only by me
    And my identity file is readable only by me

  Scenario: I can create files with funny characters
    Given I am using a temporary password store
    When I store a secret for "home/with space" with content "horsebattery"
    Then "home/with space.age" plaintext is "horsebattery"

    When I store a secret for "silly/two\nlines" with content "horsebattery"
    Then "silly/two\nlines.age" plaintext is "horsebattery"

  Scenario: I can see usage information
    When I run "moss help"
    Then  I see the string "Store and retrieve encrypted secrets"
    And I see the string "Usage: moss \[command\] \[parameters\]"
    And I see the string "add a secret to the store"

    When I run "moss kxdcjghlsdkjfhgslkdjg"
    Then  I see the string "unrecognised command. See \"moss help\""

  Scenario: argument checking
    When I run "moss show"
    Then it shows a usage message for "show"

    When I run "moss cat"
    Then it shows a usage message for "cat"
