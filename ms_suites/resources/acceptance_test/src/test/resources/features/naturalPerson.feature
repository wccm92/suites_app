Feature: Test naturalPerson
  Me as a tester need to test authentication mock-natural-person to validate the response

  Background: Set urlbase
    * def urlBase = defUrlBase
    * def path = 'natural-person'
    * def badPath = 'natural-personaaas'
    * def dataRequest = read('classpath:json/natural_person.json')
    * configure headers = { 'Content-Type': 'application/json' }
    * configure logPrettyRequest = true
    * configure ssl = true

  Scenario: Validate success sandbox natural-person
    Given url urlBase + path
    And request dataRequest
    When method post
    Then assert responseStatus == 200
    And match response.data.token == '#string'

  Scenario: Validate empty fields natural-person
      * set dataRequest.tip_doc = ""
      Given url urlBase + path
      And request dataRequest
      When method post
      Then assert responseStatus == 200
      And match response.errors[0].detail == 'Campos nulos o vacíos'

  Scenario: Validate wrong path natural-person
    Given url urlBase + badPath
    And request dataRequest
    When method post
    Then assert responseStatus == 404