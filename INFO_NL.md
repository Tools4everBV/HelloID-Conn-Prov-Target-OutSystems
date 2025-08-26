De OutSystems Target Connector maakt het mogelijk OutSystems via de Identity & Access Management (IAM)-oplossing HelloID van Tools4ever als doelsysteem te koppelen aan je bronsystemen. Deze integratie automatiseert identity management-processen, waaronder het aanmaken, wijzigen of juist verwijderen van gebruikersaccounts binnen OutSystems. In dit artikel lees je meer over deze connector, de mogelijkheden en voordelen. 

## Wat is OutSystems

OutSystems is een low-code platform van het gelijknamige bedrijf. Met behulp van dit platform kunnen gebruikers eenvoudig applicaties bouwen. Het maakt daarbij gebruik van een low-code aanpak, wat betekent dat gebruikers zelf geen code hoeven te schrijven en met behulp van een drag-and-drop-interface een applicatie kunnen opbouwen uit een breed scala aan componenten. Niet alleen verkort dit de ontwikkeltijd van applicaties, ook stelt low-code gebruikers zonder programmeerkennis in staat zelf applicaties te creëren. 

## Waarom is OutSystems koppeling handig?

Om met OutSystems aan de slag te kunnen moeten gebruikers over een account en de juiste rechten beschikken. Dankzij de koppeling tussen OutSystems, HelloID en je bronsystemen heb je naar dit proces geen omkijken en weet je zeker dat bevoegde gebruikers op het juiste moment toegang hebben tot het juiste project, wat in OutSystems ook wel een domein wordt genoemd. Het feit dat gebruikers in meerdere domeinen kunnen werken maakt de situatie extra complex. Je wilt immers met het oog op digitale veiligheid dat gebruikers alleen bij de projecten kunnen waarbij zij betrokken zijn. HelloID kan dit proces in belangrijke mate voor je automatiseren. 
De OutSystems-connector maakt het mogelijk OutSystems met diverse bronsystemen te integreren. Denk daarbij aan:

*	Active Directory
*	Entra ID (voorheen Azure AD)
*	ADP Workforce
* AFAS
*	RAET
*	NMBRS
*	SAP SuccessFactors
*	Visma.NET   

Verderop in dit artikel lees je meer over deze integraties.

## Hoe HelloID integreert met OutSystems

OutSystems koppelt als doelsysteem aan HelloID. De IAM-oplossing maakt daarbij gebruik van de REST API van OutSystems voor het ophalen en bijwerken van gegevens. De oplossingen wisselen diverse gegevens uit. Het gaat onder meer om persoonsgegevens, waaronder basisinformatie als naam, functie en contactgegevens. Denk echter ook aan toegangsrechten en groepslidmaatschappen, zoals informatie over de rechten en rollen die aan gebruikers zijn toegewezen. Daarbij is een belangrijke rol weggelegd voor de autorisatiematrix, waarin je vastlegt welke rechten je wilt toekennen op basis van functie en afdeling. HelloID kan met behulp van deze matrix het toekennen van accounts en rechten in belangrijke mate automatiseren. Tot slot wisselen OutSystems en HelloID afdelingsinformatie en de hiërarchische structuur van de organisatie met elkaar uit.

**Gebruikersaccounts aanmaken, beheren en verwijderen**

HelloID houdt je bronsystemen nauwlettend in de gaten en merkt wijzigingen zoals het toevoegen van een nieuwe werknemer zelfstandig op. HelloID maakt in dit geval automatisch een account aan voor de gebruiker en kent de juiste rechten toe. Nieuwe medewerkers beschikken hierdoor op hun eerste werkdag direct over de benodigde middelen voor het bouwen van applicaties via het low-code platform. Je primaire bronsysteem is daarbij altijd leidend. Ook neemt HelloID het beheer van accounts voor rekening. Wijzigen de gegevens van een medewerker bijvoorbeeld? Dan past de IAM-oplossing het account in OutSystems automatisch hierop aan. Loopt het dienstverband af? Dan verwijdert HelloID het OutSystems-account.

**Toegangsrechten en groepslidmaatschappen beheren**

Werknemers kunnen vanwege allerlei redenen andere rechten nodig hebben. Bijvoorbeeld indien hun functie wijzigt, zij aanvullende taken gaan uitvoeren of uit dienst treden. HelloID monitort je bronsystemen en merkt deze wijzigingen hierdoor zelfstandig op. Het past op basis van deze wijzigingen zowel het account als de toegekende rechten van een gebruiker automatisch aan. Bijvoorbeeld door toegang te verstrekken tot extra domeinen of juist bestaande rechten in te trekken. 

Ook hierbij is de autorisatiematrix leidend. Je legt een autorisatiematrix vast in business rules. Indien nodig kun je uiteraard afwijken van de autorisatiematrix, zodat je uitzonderingen kunt maken. Bijvoorbeeld indien een medewerker tijdelijk betrokken is bij een project. 

Bij de integratie tussen HelloID en OutSystems sta je zelf aan de knoppen. Dat betekent onder meer dat je de gegevensuitwisseling tussen de twee oplossingen kunt aanpassen aan de specifieke behoeften van jouw organisatie. Zo kan je instellen dat je bepaalde gegevensvelden alleen onder specifieke voorwaarden laat synchroniseren. Of dat je specifieke rollen en rechten automatisch toewijst op basis van je bedrijfsstructuur.

## HelloID voor OutSystems helpt je met

**Accounts sneller aanmaken:** HelloID maakt automatisch een account aan in OutSystems indien je een nieuwe gebruiker toevoegt aan je bronsysteem. Je hoeft hiervoor geen handmatige handelingen uit te voeren; HelloID detecteert wijzigingen in je bronsysteem automatisch en voert op basis hiervan de benodigde handelingen uit. Nieuwe medewerkers beschikken hierdoor op hun eerste werkdag direct over de benodigde middelen. Loopt het dienstverband van een medewerker af? Dan merkt HelloID ook deze mutatie op en deactiveert automatisch het OutSystems-account van de gebruiker.

**Accountbeheer foutloos maken:** HelloID automatiseert het beheer van zowel accounts als toegangsrechten in OutSystems, en voorkomt zo menselijke fouten. Belangrijk, want een simpele fout kan ertoe leiden dat gebruikers geen toegang (meer) hebben tot het low-code platform of juist dat het platform voor onbevoegden toegankelijk is doordat hun toegang niet tijdig is geblokkeerd. 

**Je serviceniveau en beveiliging verbeteren:** De koppeling maakt geautomatiseerde en gecontroleerde processen op het gebied van accountbeheer mogelijk. Zo til je de beveiliging naar een hoger niveau, onder meer door het tijdig blokkeren van accounts van uitgestroomde medewerkers. Ook stel je zeker dat gebruikers nooit meer toegang hebben dan noodzakelijk. Belangrijk, want indien een aanvaller toegang krijgt tot een gebruikersaccount wil je deze zo min mogelijk opties bieden. Tegelijkertijd verbeter je je serviceniveau doordat gebruikers automatisch op het juiste moment over de juiste accounts en toegangsrechten beschikken.

## OutSystems via HelloID koppelen met systemen

HelloID maakt het integreren van diverse systemen met OutSystems mogelijk. De integraties verbeteren en versterken het beheer van gebruikersaccounts en autorisaties, onder meer dankzij consistente processen en automatisering. Enkele voorbeelden van veelvoorkomende integraties zijn:

* **Microsoft Active Directory/Entra ID - OutSystems koppeling:** De Microsoft Active Directory/Entra ID - OutSystems koppeling integreert Microsoft Active Directory en/of Entra ID via HelloID als bronsysteem aan OutSystems. De koppeling maakt onder meer Single Sign-On (SSO) mogelijk, waarvoor de gebruikersnaam of het e-mailadres uit Microsoft Active Directory of Entra ID wordt gehaald. Indien in OutSystems Azure Authentication niet is ingeschakeld, levert HelloID ook een wachtwoord aan.

* **ADP Workforce Management - OutSystems koppeling:** De ADP Workforce Management – OutSystems koppeling integreert de HR- en payrolloplossing van ADP Nederland via HelloID met OutSystems. De IAM-oplossing van Tools4ever monitort daarbij ADP Workforce Management en merkt wijzigingen zelfstandig op. Op basis van deze wijzigingen voert het de benodigde mutaties door in OutSystems. Zo heb je geen omkijken naar het beheer van gebruikers en rechten, en kunnen werknemers altijd bij de juiste domeinen in OutSystems. 
 

HelloID ondersteunt ruim 200 connectoren, waarmee de IAM-oplossing een breed scala aan bronsystemen aan OutSystems kan koppelen. Je kunt OutSystems dan ook met nagenoeg alle populaire systemen integreren. Ons portfolio met connectoren is continu in ontwikkeling. Benieuwd naar de mogelijkheden? Bekijk <a href="https://www.tools4ever.nl/connectoren/">hier</a> een overzicht van alle beschikbare connectoren op onze website. 
