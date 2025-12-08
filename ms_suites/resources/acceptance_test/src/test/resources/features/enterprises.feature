Feature: Test enterprises
  Me as a tester need to test authentication mock-enterprises to validate the response

  Background: Set urlbase
    * def urlBase = defUrlBase
    * def path = 'enterprises'
    * def badPath = 'enter'
    * def dataRequest = read('classpath:json/enterprises.json')
    * configure headers = { 'Content-Type': 'application/json' }
    * configure logPrettyRequest = true
    * configure ssl = true

  Scenario: Validate success sandbox enterprises
    Given url urlBase + path
    And request dataRequest
    When method post
    Then assert responseStatus == 200
    And match response.data.token == '#string'

  Scenario: Validate empty fields enterprises
      * set dataRequest.tip_doc = ""
      Given url urlBase + path
      And request dataRequest
      When method post
      Then assert responseStatus == 200
      And match response.errors[0].detail == 'Campos nulos o vacíos'

  Scenario: Validate wrong path enterprises
    Given url urlBase + badPath
    And request dataRequest
    When method post
    Then assert responseStatus == 404