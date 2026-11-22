// Snapshot of organization names from the source directories below.
// Keep IDs stable when correcting a name or adding an alias.
const clubCatalogVerifiedOn = '2026-11-21';
const clubCatalogSources = <int, (String, String)>{
  1: (
    "Athletics and recreation",
    "https://ssmu.ca/clubs/athletics-recreation-clubs/",
  ),
  2: (
    "Charity and environment",
    "https://ssmu.ca/clubs/charity-environment-clubs/",
  ),
  3: (
    "Community outreach and volunteering",
    "https://ssmu.ca/clubs/community-outreach-and-volunteering-clubs/",
  ),
  4: (
    "Fine arts, dance and performance",
    "https://ssmu.ca/clubs/performing-finearts-clubs/",
  ),
  5: ("Health and wellness", "https://ssmu.ca/clubs/health-wellness-clubs/"),
  6: (
    "Language and publications",
    "https://ssmu.ca/clubs/language-publications/",
  ),
  7: (
    "Leisure activities and hobbies",
    "https://ssmu.ca/clubs/hobby-leisure-clubs/",
  ),
  8: (
    "Networking and leadership",
    "https://ssmu.ca/clubs/networking-and-leadership-development-clubs/",
  ),
  9: (
    "Political and social activism",
    "https://ssmu.ca/clubs/political-socialactivism-clubs/",
  ),
  10: ("Religion and culture", "https://ssmu.ca/clubs/religion-culture-clubs/"),
  11: (
    "University student societies",
    "https://www.mcgill.ca/cle/life-campus/student-led-clubs-societies-and-associations",
  ),
  12: (
    "Engineering",
    "https://www.mcgill.ca/engineering/students/undergraduate/student-life/student-groups",
  ),
  13: (
    "Desautels",
    "https://www.mcgill.ca/desautels/programs/bcom/student-life-resources/student-clubs",
  ),
  14: ("Recreation", "https://recreation.mcgill.ca/sport-clubs"),
  15: ("Student government", "https://ssmu.ca/how-we-run/elections/"),
  16: ("Engineering", "https://euswiki.mcgilleus.ca/clubs/junior-council/"),
  17: ("Arts", "https://ausmcgill.com/committees/"),
  18: ("Science", "https://susmcgill.ca/departmental-associations"),
  19: ("Computer Science", "https://mcgill-csus.ca/fyc"),
  20: ("Engineering", "https://ecsess.mcgilleus.ca/"),
  21: ("Bioengineering", "https://buss.mcgilleus.ca/Getting%20Involved.html"),
  22: (
    "Mechanical Engineering",
    "https://euswiki.mcgilleus.ca/departmental-societies/mcgill-association-of-mechanical-engineers/",
  ),
  23: ("Desautels", "https://www.musmcgill.com/copy-of-consulting-strategy"),
  24: ("Education", "https://www.edusmcgill.com/committees"),
  25: ("Political Science", "https://www.pssamcgill.ca/our-constitution"),
  26: (
    "Engineering",
    "https://euswiki.mcgilleus.ca/departmental-societies/electrical-computer-and-software-engineering-stude/",
  ),
  27: ("Computer Science", "https://linktr.ee/mcgillcsus"),
};

// ID | official display name | source keys | organization type | aliases…
const clubCatalogRows = r'''
ssmu-961-calling|961 Calling|8|club
ssmu-alegria-contemporary-ballet-company|Alegria Contemporary Ballet Company|4|club
engineering-architecture-students-society-asa|Architecture Students Society (ASA)|12|studentSociety|ASA
ssmu-balkan-students-society-of-mcgill|Balkan Students’ Society of McGill|10|club
ssmu-baltic-students-society-bss|Baltic Students Society (BSS)|10|club|BSS
ssmu-bangladesh-students-association-bsa|Bangladeshi Students Association (BSA)|10|club|BSA
ssmu-belgian-students-society-bss|Belgian Students’ Society (BSS)|10|club|BSS
ssmu-beyond-borders-club|Beyond Borders Club|3|club
ssmu-ssmu-beyond-me|Beyond Me|3|club
engineering-bioengineering-undergraduate-students-society-buss|Bioengineering Undergraduate Students Society (BUSS)|12|studentSociety|BUSS
engineering-bioresource-engineering-students-society-bess|Bioresource Engineering Students Society (BESS)|12|studentSociety|BESS
ssmu-black-muslim-initiative-at-mcgill-university|Black Muslim Initiative at McGill University|10|club
ssmu-black-varsity-association|Black Varsity Association|8|club
ssmu-mcgill-students-blockchain-association|Blockchain at McGill|8|club
ssmu-boost|BOOST|3|club
ssmu-borderless-world-volunteers|Borderless World Volunteers|2,3|club
engineering-brewing-club|Brewing Club|12|club
ssmu-british-appreciation-society-bas|British Society McGill (BritSoc)|10|club
ssmu-mcgill-students-business-review|Business Review, McGill Students’|6,13|club|McGill Business Review
buss-first-year-council|BUSS First-Year Council|21|firstYearCouncil|BUSS FYC|Bioengineering First Year Council
ssmu-canadian-black-nurses-alliance-mcgill-chapter|Canadian Black Nurses Alliance McGill Chapter|8|club
ssmu-canadian-coalition-for-global-health-research-cagh-mcgill-students-chapter-formerly-canadian-council-for-global-health-research-ccghr-mcgill-student-chapter|Canadian Coalition for Global Health Research (CAGH) McGill Students Chapter|3|club|CAGH
ssmu-canadian-nursing-students-association-cnsa|Canadian Nursing Students Association (CNSA)|8|club|CNSA
ssmu-caribbean-students-society-of-mcgill-university-css|Caribbean Students Society of McGill University (CSS)|10|club|CSS
desautels-casco-mcgill|Casco McGill|13|club
ssmu-chabad-house-student-society-2|Chabad at McGill|10|club
ssmu-change-for-change-ssmu|Change for Change SSMU|3|club
engineering-chemical-engineering-students-society-chess|Chemical Engineering Students Society (ChESS)|12|studentSociety
ssmu-mcgill-students-chinese-brush-arts-club-mscbac|Chinese Brush Arts Club|4|club
ssmu-chinese-students-and-scholars-association-at-mcgill-university-cssa|Chinese Students and Scholars Association at McGill University|10|club
ssmu-chromatones-a-cappella|Chromatones A Cappella|4|club
ssmu-circle-of-fashion-formerly-mode-mcgill|Circle of Fashion McGill|4|club
engineering-civil-engineering-undergraduate-society-ceus|Civil Engineering Undergraduate Society (CEUS)|12|studentSociety|CEUS
ssmu-club-de-debat-francophone|Club de débat francophone|8|club
engineering-co-op-mining-engineering-undergraduate-society|Co-op Mining Engineering Undergraduate Society|12|studentSociety
ssmu-cocoa-cacao-ssmu|Cocoa & Cacao|7|club
ssmu-commodity-trading-group|Commodity Trading Group|8|club
ssmu-comparative-healthcare-systems-program|Comparative Healthcare Systems Program (CHSP)|5|club|CHSP
ssmu-connectus-mcgill-students|ConnectUs McGill Students|8|club
desautels-consulting-academy-mcgill|Consulting Academy McGill|13|club
ssmu-contemporary-review-of-genocide-and-political-violence|Contemporary Review of Genocide and Political Violence|6|club
ssmu-counterpoint|Counterpoint|6|club
ssmu-critical-media|Critical Media|6|club
csus-first-year-council|CSUS First-Year Council|19,27|firstYearCouncil|CSUS FYC|Computer Science First Year Council
ssmu-cycling-mcgill-2|Cycling @ McGill|1|club
ssmu-mcgill-dance-pack|Dance Pack|4|club
ssmu-democrats-abroad-mcgill-2|Democrats at McGill|9|club
desautels-desautels-accounting-society|Desautels Accounting Society|13|club
desautels-desautels-african-business-initiative|Desautels African Business Initiative|13|club
desautels-desautels-sustainability-network|Desautels Sustainability Network|13|club
desautels-desautels-women-in-business|Desautels Women in Business|13|club
ssmu-discussion-collective-mcgill-students-msdc|Discussion Collective, McGill Students’ (MSDC)|8|club|MSDC
ssmu-diversity-in-math|Diversity In Math|9|club
ssmu-dragon-boat-z-2|Dragon Boat Z|1|club
ssmu-dsign-lab|Dsign Lab|4|club
desautels-dtech|DTech|13|club
ecsess-bits|ECSESSBits|20,26|firstYearCommittee|ECSESS Bits|ECSESS First Year Council|ECSESS First Year Committee
ssmu-effusion-a-cappella|Effusion A Cappella|4|club
ssmu-egyptian-students-association-2|Egyptian Students Association|10|club
engineering-electrical-computer-software-engineering-student-society-ecsess|Electrical, Computer, & Software Engineering Student Society (ECSESS)|12|studentSociety|ECSESS
ssmu-mcgill-students-for-enactus|Enactus McGill|3,8|club
engineering-engineering-undergraduate-society-eus|Engineering Undergraduate Society (EUS)|12|facultyAssociation|EUS
engineering-engineers-in-action|Engineers in Action|12|club
desautels-entertainment-management-conference|Entertainment Management Conference|13|club
ssmu-esg-mcgill|ESG McGill|2,8,9|club
eus-junior-council|EUS Junior Council (JC)|16|firstYearCommittee|Engineering Junior Council|EUS JC|EUS First-Year Committee
ssmu-expanding-economics|Expanding Economics|9|club
ssmu-falun-dafa-at-mcgill|Falun Dafa at McGill|5|club
desautels-fashion-business-uncovered|Fashion Business Uncovered|13|club
edus-fyre|First-Year Representatives of Education (FYRE)|24|firstYearCommittee|EdUS FYRE|EdUS First Year Committee
sus-fuss|First-Year Undergraduate Science Society (FUSS)|18|firstYearSociety|SUS FUSS|SUS First-Year Council|First Year Undergraduate Science Students Society
ssmu-fit-for-a-cause|Fit For a Cause|2|club
ssmu-flag-football-club|Flag Football Club|1|club
ssmu-folio-magazine|Folio Magazine|6|club
ssmu-franc-jeu-2|Franc-Jeu|4|club
aus-fearc|Freshmen Events Academic and Representative Committee (FEARC)|17|firstYearCommittee|AUS FEARC|AUS First-Year Committee|First Year Events Academic and Representative Council
ssmu-friends-of-m%c3%a9decins-sans-fronti%c3%a8res-ssmu|Friends of Médecins Sans Frontières (MSF) – SSMU|9|club|MSF
engineering-gamedev|GameDev|12|club
ssmu-girls-for-ghana|Girls For Ghana|2|club
ssmu-global-china-connection-2|Global China Connection (GCC)|8|club|GCC
ssmu-hack4impact|Hack4Impact|3|club
ssmu-heal-and-hope|Heal and Hope|3|club
ssmu-health-occupation-students-of-america-mcgill-hosa|Health Occupation Students of America McGill (HOSA)|8|club|HOSA
ssmu-heforshe-mcgill|HeForShe McGill|9|club
ssmu-mcgill-hillel-jewish-students-association|Hillel McGill|10|club
ssmu-hong-kong-student-network-hksn|Hong Kong Student Network|10|club
ssmu-igem|iGEM|8,12|designTeam|McGill iGem
ssmu-indian-students-association-of-mcgill-2|Indian Students Association (ISA)|10|club|ISA
ssmu-indigenous-student-alliance|Indigenous Student Association|9|club
ssmu-indonesia-student-association-at-mcgill|Indonesia Student Association at McGill|10|club
ssmu-inertia-modern-dance-collective-ssmu|Inertia Modern Dance Collective|4|club
engineering-institute-of-electrical-and-electronics-engineers-ieee|Institute of Electrical and Electronics Engineers (IEEE)|12|club|IEEE
desautels-international-management-association|International Management Association|13|club
ssmu-iraqi-students-society-at-mcgill|Iraqi Student’s Society at McGill|10|club
ssmu-mcgill-students-chapter-of-unleash-the-noise|Jack.Org McGill Students Chapter|5|club
ssmu-japanese-students-association-jsa|Japanese Students Association (JSA)|10|club|JSA
desautels-jed-consulting|JED Consulting|13|club
ssmu-journalists-for-human-rights-mcgill-jhr|Journalists for Human Rights: McGill University Student|9|club
ssmu-junior-hong-kong-business-association|Junior Hong Kong Business Association|8|club
ssmu-k-rave|K-RAVE|4|club
ssmu-mcgill-korean-students-educational-and-cultural-association-meca|Korean Students’ Association|10|club
ssmu-mcgill-korean-students-society|Korean Students’ Society|10|club
ssmu-lassociation-des-etudiants-francais-de-mcgill|L’Association des Étudiants Français de McGill|10|club
ssmu-les-muses-chorales-2|Les Muses Chorale|4|club
ssmu-lettuce-club|Lettuce Club|7,8|club
ssmu-young-liberals-of-canada-mcgill|Liberal McGill|9|club
ssmu-little-forests-mcgill|Little Forests McGill|2|club
ssmu-world-university-services-canada-wusc|Local Committee for the World University Services of Canada (WUSC) at McGill University|2|club|WUSC
ssmu-lotus-dance-initative|Lotus Initiative|5|club
mcgill-mcgss|Macdonald Campus Graduate Students’ Society|11|campusSociety|MCGSS
mcgill-mcss|Macdonald Campus Students’ Society|11|campusSociety|MCSS
ssmu-malaysian-and-singaporean-students-association-2|Malaysian and Singaporean Students’ Association (MASSA)|10|club|MASSA
mame-first-year-council|MAME First-Year Council|22|firstYearCouncil|MAME FYC|Mechanical Engineering First Year Council
desautels-mus|Management Undergraduate Society|13|facultyAssociation|MUS
engineering-materials-engineering-undergraduate-society-meus|Materials Engineering Undergraduate Society (MEUS)|12|studentSociety|MEUS
ssmu-mcconnect|McConnect|3|club
ssmu-mcgill-african-students-society-mass-2|McGill African Students Society (MASS)|10|club|MASS
ssmu-mcgill-armenian-students-association-2|McGill Armenian Students Association (MASA)|10|club|MASA
ssmu-mcgill-arts-collective|McGill Arts Collective|4|club
mcgill-maces|McGill Association of Continuing Education Students|11|campusSociety|MACES
engineering-mcgill-association-of-mechanical-engineers-mame|McGill Association of Mechanical Engineers (MAME)|12|studentSociety|MAME
ssmu-mcgill-association-of-north-american-born-asians-manaba|McGill Association of North American Born Asians (MANABA)|10|club|MANABA
ssmu-mcgill-badminton-club|McGill Badminton Club|1|club
engineering-mcgill-baja-racing|McGill Baja Racing|12|designTeam
engineering-mcgill-biodesign|McGill Biodesign|12|designTeam
ssmu-mcgill-biomechanics-club|McGill Biomechanics Club|8,12|club|McGill Biomechanics
ssmu-mcgill-board-game-students-society|Mcgill Board Game Students’ Society|7|club
ssmu-book-club|McGill Book Club|7|club
engineering-mcgill-bridge-building|McGill Bridge Building|12|designTeam
ssmu-mcgill-calisthenics-club|McGill Calisthenics Club|5|club
engineering-mcgill-chem-e-car|McGill Chem-E Car|12|designTeam
ssmu-montreal-childrens-health-alliance-at-mcgill-mcham-2|McGill Children’s Health Alliance of Montreal|3|club
ssmu-mcgill-chinese-orchestra|McGill Chinese Orchestra|4|club
ssmu-chinese-students-society|McGill Chinese Students Society (MCSS)|10|club|MCSS
ssmu-mcgill-choral-society-2|McGill Choral Society|4|club
ssmu-mcgill-christian-fellowship-mcf|McGill Christian Fellowship (MCF)|10|club|MCF
ssmu-mcgill-climbing-club|McGill Climbing Club|1|club
ssmu-mcgill-students-for-un-women-canada-national-committee|McGill Collective for Gender Equality|9|club
engineering-mcgill-concrete-canoe|McGill Concrete Canoe|12|designTeam
desautels-mcgill-consulting-association|McGill Consulting Association|13|club
ssmu-mcgill-cures-cancer|McGill Cures Cancer|2|club
ssmu-debating-union|McGill Debating Union|8|club
ssmu-mcgill-design-consultancy|McGill Design Consultancy|4|club
ssmu-mcgill-dharma-society|McGill Dharma Society|10|club
ssmu-72919|McGill DJ Society|4|club
engineering-mcgill-drones-and-vertical-flight-society|McGill Drones and Vertical Flight Society|12|designTeam
ssmu-mcgill-eloquence|McGill Eloquence|8|club
ssmu-energy-association-2|McGill Energy Association|2|club
engineering-mcgill-engineering-raclette-team|McGill Engineering Raclette Team|12|club
ssmu-mcgill-e-sports-students-society|McGill Esports Student’s Association|1|club|McGill eSports Student Association|MESA
engineering-mcgill-flying-club|McGill Flying Club|12|club
engineering-mcgill-formula-electric|McGill Formula Electric|12|designTeam
ssmu-mcgill-hellenic-students-association-2|McGill Hellenic Students Association|10|club
ssmu-icon-2|McGill ICON|10|club
ssmu-misn|McGill International Students Network (MISN)|8|club|MISN
desautels-mcgill-investment-club|McGill Investment Club|13|club
ssmu-mcgill-iranian-student-association-misa|McGill Iranian Student Association (MISA)|10|club|MISA
ssmu-mcgill-ismaili-students-association-misa|McGill Ismaili Students Association (ISA)|10|club|ISA
ssmu-mcgill-italian-student-society|McGill Italian Student Society|10|club
ssmu-mcgill-karateka|McGill Karateka|1|club
ssmu-mcgill-leadership-club|McGill Leadership Club|8|club
ssmu-lebanese-students-association-mcgill|McGill Lebanese Students Association (LSA)|10|club|LSA
desautels-mcgill-marketing-network|McGill Marketing Network|13|club
ssmu-mcgill-model-parliament|McGill Model Parliament|9|club
ssmu-mcgill-quidditch-team|McGill Muggle Quidditch Club|1|club
ssmu-mcgill-naginata-club|McGill Naginata Club|1|club
ssmu-mcgill-nourish|McGill Nourish|2|club
ssmu-mcgill-padel-club|Mcgill Padel Club|1|club
ssmu-mcgill-students-chapter-of-american-association-of-pharmaceutical-sciences-aaps|McGill Pharmaceutical Career Student Network (PCSN)|5|club|PCSN
ssmu-mcgill-pickleball-club|McGill Pickleball Club|1|club
ssmu-mcgill-poker-studies-club|McGill Poker Studies Club|7|club
ssmu-the-mcgill-polish-students-association-mpsa|McGill Polish Students’ Association (MPSA)|10|club|MPSA
ssmu-pre-dental-society-2|McGill Pre-Dental Students’ Society (MPDSS)|8|club|MPDSS
ssmu-mcgill-pre-law-students-society-mpls|McGill Pre-Law Students’ Society (MPLS)|8|club|MPLS
engineering-mcgill-product-management-association|McGill Product Management Association|12|club
ssmu-mcgill-respiratory-wellness-initiative|McGill Respiratory Wellness Initiative|8|club
engineering-mcgill-robotics|McGill Robotics|12|designTeam
engineering-mcgill-rocket-team|McGill Rocket Team|12|designTeam
ssmu-sign-language|McGill Sign Language Club|6|club
ssmu-mcgills-sikh-students-association|McGill Sikh Students’ Association|10|club
desautels-mcgill-sports-management-club|McGill Sports Management Club|13|club
ssmu-ssmu-boxing-club-2|McGill Student Boxing Club|1|club
ssmu-mcgill-student-entrepreneurship-society|McGill Student Entrepreneurship Society|8|club
ssmu-mcgill-student-street-dancers-mssd|McGill Student Street Dancers (MSSD)|4|club|MSSD
ssmu-tennis-club|McGill Student Tennis Club|1|club
ssmu-mcgill-students-actuarial-association|McGill Students’ Actuarial Association (MSAA)|8|club|MSAA
ssmu-mcgill-students-anime-club|McGill Students’ Anime Club|7|club
ssmu-mcgill-students-cancer-society|McGill Students’ Cancer Society (MSCS) – Relay for Life|2|club|MSCS
ssmu-mcgill-students-chapter-of-amnesty-international|McGill Students Chapter for Amnesty International|9|club
ssmu-mcgill-students-chapter-for-scientista|McGill Students Chapter for Scientista|8|club
ssmu-mcgill-students-chapter-of-jam-for-justice|McGill Students Chapter of Jam for Justice|3|club
ssmu-mcgill-students-for-the-canadian-red-cross|McGill Students Chapter of the Canadian Red Cross|2|club
ssmu-institute-for-health-care-improvement|McGill Students Chapter of the Institute for Health Care Improvement|5|club
ssmu-universities-allied-for-essential-medicines-uaem|McGill Students Chapter of Universities Allied for Essential Medicines (UAEM)|5|club|UAEM
ssmu-war-child|McGill Students Chapter of War Child|9|club
ssmu-mcgill-students-chess-club|McGill Students’ Chess Club|7|club
ssmu-classical-music-club-2|McGill Students’ Classical Music Club (CMC)|4|club|CMC
ssmu-mcgill-students-comedy-club|McGill Students Comedy Club|4|club
ssmu-mcgill-students-cricket-club|McGill Students Cricket Club|1|club
ssmu-mcgill-students-culinary-society|McGill Students Culinary Society|7|club
ssmu-mcgill-students-for-best-buddies|McGill Students for Best Buddies|3|club
ssmu-mcgill-students-for-sports-legacy-institute|McGill Students for Concussion Legacy Foundation|2|club
ssmu-mcgill-students-for-fimrc-foundation-for-the-international-medical-relief-of-children|McGill Students for FIMRC (Foundation for International Medical Relief of Children)|2|club
ssmu-mcgill-students-for-geriatric-health|McGill Students for Geriatric Health|3|club
ssmu-mcgill-students-for-greenpeace|McGill Students for Greenpeace|2|club
ssmu-liberty-in-north-korea|McGill Students for HanVoice|9|club
ssmu-mcgill-students-chapter-of-heart-4-heart|McGill Students for Heart 4 Heart|2|club
ssmu-mcgill-students-for-make-a-wish|McGill Students for Make-A-Wish|2|club
ssmu-mcgill-students-for-montreal-shelters|McGill Students for Montreal Shelters|3|club
ssmu-mcgill-students-for-oral-health|McGill Students for Oral Health|5|club
ssmu-mcgill-students-for-parkinsons|McGill Students’ for Parkinson’s Awareness|5|club
ssmu-mcgill-students-for-partners-in-health-pih|McGill Students for Partners in Health (PIH)|5|club|PIH
ssmu-mcgill-students-for-right-to-play|McGill Students for Right to Play|2|club
ssmu-project-go|McGill Students for Santropol Roulant|3|club
ssmu-69058|McGill Students for Science-based Addiction Treatment (MSSAT)|5|club|MSSAT
ssmu-mcgill-students-for-the-open-door-montreal|McGill Students for The Open Door Montreal|3|club
ssmu-mcgill-students-for-think-pink|McGill Students for Think Pink|2|club
ssmu-mcgill-students-for-unicef|McGill Students for UNICEF|2|club
ssmu-mcgill-students-for-uyghur-solidarity|McGill Students for Uyghur Solidarity|9|club
ssmu-mcgill-students-for-wildlife-conservation|McGill Students for Wildlife Conservation|2|club
ssmu-mcgill-students-for-world-vision|McGill Students for World Vision|2|club
ssmu-mcgill-students-go-club|McGill Students’ Go Club|7|club
ssmu-graduate-management-consulting-association|McGill Students Graduate Management Consulting Association (GMCA)|8|club|GMCA
ssmu-mcgill-students-improv|McGill Students’ Improv|4|club
ssmu-mcgill-students-knitting-club|McGill Students Knitting Club|7|club
ssmu-mcgill-students-mafia-club|McGill Students’ Mafia Club|7|club
ssmu-mcgill-students-orthodox-christian-fellowship|McGill Students Orthodox Christian Fellowship (OCF)|10|club|OCF
ssmu-mcgill-students-outdoors-club-moc|McGill Student’s Outdoors Club (MOC)|1,14|club|MOC|McGill Olympic Club (MOC)
ssmu-mcgill-students-running-club-mcrun|McGill Students Running Club – McRun|1|club
ssmu-mcgill-students-scout-association|McGill Student’s Scout Association|8|club
ssmu-mcgill-students-societea|McGill Students’ SocieTea|7|club
ssmu-mcgill-students-supporting-the-heart-and-stroke-foundation-2|McGill Students Supporting the Heart and Stroke Foundation|5|club
ssmu-mcgill-students-trading-society|McGill Students Trading Society (MSTS)|8|club|MSTS
ssmu-sketching-club-2|McGill Students’ Visual Arts Society|4|club
ssmu-mcgill-students-yu-gi-oh-club|McGill Students Yu-Gi-Oh Club|7|club
ssmu-swing-kids-ssmu|McGill Swing Kids (MSK)|4|club|MSK
ssmu-mcgill-table-tennis-club|McGill Table Tennis Club|1|club
ssmu-taiwanese-students-association|McGill Taiwanese Students’ Association (MTSA)|10|club|MTSA
ssmu-mcgill-thaqalayn-muslim-students-association|McGill Thaqalayn Muslim Students’ Association|10|club
recreation-mcgill-triathlon-club-mtc|McGill Triathlon Club (MTC)|14|club|MTC
ssmu-trivia-club-2|McGill Trivia Club|7|club
ssmu-mcgill-ukrainian-students-association-musa|McGill Ukrainian Students Association (MUSA)|10|club|MUSA
ssmu-ultimate-club-2|McGill Ultimate Club|1|club
ssmu-mcgill-students-association-for-speech-and-language-disorders-msasld|McGill Undergraduates for Communication Disorders Awareness|3|club
ssmu-mcgill-university-filipino-asian-students-association-mufasa-2|McGill University Filipino Asian Students Association (MUFASA)|10|club|MUFASA
ssmu-mcgill-university-photography-students-society-mupss|McGill University Photography Students’ Society (MUPSS)|4|club|MUPSS
ssmu-mcgill-university-student-hospital-volunteer-club-mushvc|McGill University Student Hospital Volunteer Club (MUSHVC)|3|club|MUSHVC
desautels-mcgill-ventures|McGill Ventures|13|club
ssmu-mcgill-veterans-association|McGill Veterans Association|9|club
ssmu-mcgill-vietnamese-students-association-2|McGill Vietnamese Students Association (MVSA)|10|club|MVSA
ssmu-mcgill-students-wine-society|McGill Wine Society|7|club
ssmu-the-mcgill-students-society-of-women-in-computer-science-mcwics|McGill Women in Computer Science (McWiCS)|8|club
ssmu-mcgill-women-in-leadership-students-association-mwil|McGill Women in Leadership Students Association (MWIL)|8|club|MWIL
ssmu-mcgill-womens-flag-football-club|McGill Women’s Flag-Football Club|1,5|club
ssmu-students-society-of-hackers-at-mcgill-university|McHacks – Hacks at Students’ Society of McGill University|8|club
ssmu-mcgill-students-we-are-young-mcsway|Mcsway Poetry Collective|6|club
ssmu-mealcare|MealCare|2|club
ssmu-medspecs-2|Medical Perspectives (MedSpecs)|8|club
ssmu-medlife-mcgill|MEDLIFE McGill|3|club
ssmu-mena-policy-and-research-association-for-mcgill-students|MENA Policy and Research Association for McGill Students|10|club
ssmu-montreal-di-majesty|Montreal Di Majesty|4|club
ssmu-montreal-heart-of-the-city-piano-program-2|Montreal Heart of the City Piano Program (MHCPP)|3|club|MHCPP
ssmu-moroccan-students-society|Moroccan Students’ Society|10|club
ssmu-mosaica-ssmu|Mosaica Dance Company|4|club
ssmu-multi-ethnic-student-alliance|Multi-Ethnic Student Alliance|10|club
mus-first-year-involvement-team|MUS First-Year Involvement Team (FIT)|23|firstYearCommittee|MUS FIT|Management First-Year Team
ssmu-muslim-students-association-msa|Muslim Students’ Association (MSA)|10|club|MSA
engineering-national-organization-for-business-and-engineering|National Organization for Business and Engineering|12|club
engineering-national-society-of-black-engineers-nsbe|National Society of Black Engineers (NSBE)|12|club|NSBE
ssmu-nazun-challah-for-hunger|Nazun (Challah for Hunger)|2|club
ssmu-mcgill-students-for-the-ndp|New Democratic Party (NDP) McGill|9|club|NDP
ssmu-newman-students-society-2|Newman Catholic Students’ Society|10|club
desautels-nord-consulting|NORD Consulting|13|club
ssmu-nordic-culture-club|Nordic Culture Club|10|club
desautels-p-h-assion|P[h]assion|13|club
ssmu-pakistani-students-association-psa|Pakistani Students Association (PSA)|10|club|PSA
ssmu-palestinian-cultural-club|Palestinian Cultural Club|10|club
ssmu-parks-canada-campus-club|Parks Canada Campus Club|2|club
ssmu-peace-by-p-e-a-c-e-montreal|Peace by P.E.A.C.E. Montreal|3|club
desautels-pennydrops|Pennydrops|13|club
ssmu-players-theatre|Players’ Theatre|4|club
ssmu-water-polo-club-poseidon-water-polo|Poseidon Water Polo|1|club
mcgill-pgss|Post-Graduate Students’ Society|11|campusSociety|PGSS
ssmu-power-to-change|Power to Change (P2C)|10|club|P2C
ssmu-projet-montreal-mcgill-students-association|Projet Montréal McGill Students Association|3,9|club
engineering-promoting-opportunities-for-women-in-engineering-powe|Promoting Opportunities for Women in Engineering (POWE)|12|club|POWE
pssa-first-year-council|PSSA First-Year Council|25|firstYearCouncil|PSSA FYC|Political Science First Year Council
engineering-queer-engineer|Queer Engineer|12|club
desautels-real-estate-club|Real Estate Club|13|club
engineering-reboot-mcgill|Reboot McGill|12|club
ssmu-recreational-dance-company|Recreational Dance Company (RDC)|4|club|RDC
ssmu-redpath-museum-club-2|Redpath Museum Society|7|club
desautels-redpoint-capital|RedPoint Capital|13|club
ssmu-reform-and-resettle-mcgill-students-chapter|Reform and Resettle McGill Students Chapter|2|club
ssmu-research-and-sustainability-network|Research and Sustainability Network|8|club
ssmu-revolutionary-communist-party-mcgill|Revolutionary Communist Party McGill|9|club
ssmu-rotaract-club-of-downtown-montreal|Rotaract Students’ Club|3|club
ssmu-salseros-2|Salseros McGill|4|club
ssmu-herbivore-society-for-peace-and-justice|SCALE: Student Club for Animal Liberation and Ethics|9|club
ssmu-school-of-music-montreal-somm|School of Music Montreal (SoMM)|4|club
ssmu-shes-the-first|She’s the First|2|club
ssmu-simplydonate|SimplyDonate|2|club
ssmu-sky-campus-happiness-at-mcgill|SKY Campus Happiness at McGill|5|club
ssmu-socialist-fightback-club|Socialist Fightback Club|9|club
ssmu-socratic-discussion-club|Socratic Discussion Club|8|club
ssmu-soulstice-a-cappella|Soulstice a Cappella|4|club
ssmu-spanish-and-latin-american-students-association-of-mcgill-university-slasa|Spanish and Latin American Students’ Association of McGill University (SLASA)|10|club|SLASA
ssmu-speak-to-lead|Speak to Lead (Formerly McGill Students for Lead to Speak)|8|club|McGill Students for Lead to Speak
ssmu-first-year-council|SSMU First-Year Council|15|firstYearCouncil|SSMU FYC|First Year Council|FYC
ssmu-ssmu-football-enthusiasts-club|SSMU Football Enthusiasts’ Club|1|club
ssmu-ssmu-power-lifting|SSMU Powerlifting Club|1|club
ssmu-ssmu-ski-and-snowboard-club|SSMU Ski and Snowboard Club|1|club
ssmu-ssmu-symphonic-band-club|SSMU Symphonic Band Club|4|club
ssmu-student-education-for-environmental-development-seed|Student Education for Environmental Development (SEED)|3|club|SEED
ssmu-femmedere|Student Nutrition Accessibility Club (Femmedere)|5|club
ssmu-student-research-initiative|Student Research Initiative (SRI)|8|club|SRI
ssmu-students-association-of-multiple-sclerosis|Student’s Association for Multiple Sclerosis|2|club
ssmu-students-offering-support-sos-2|Students Offering Support (SOS)|8|club|SOS
mcgill-ssmu|Students’ Society of McGill University|11|campusSociety|SSMU
desautels-suits-u|Suits U|13|club
ssmu-swab-the-world-mcgill|Swab The World Mcgill|3|club
ssmu-mcgill-students-chapter-of-swimability|Swimming With A Mission (SWAM) Montreal|3|club|SWAM
ssmu-synesthasia|Synesthesia|2|club
ssmu-syrian-echoes-of-freedom|Syrian Echoes of Freedom|9|club
ssmu-syrian-students-association-ssa-2|Syrian Students’ Association (SSA)|10|club|SSA
ssmu-tamil-students-association-of-mcgill-tamill|Tamill (TSA) -Tamil Students’ Association|10|club|TSA
ssmu-mcgill-tashan|Tashan Dance Company|4|club
ssmu-the-association-of-canadian-korean-scientists-and-engineers-akcse|The Association of Canadian Korean Scientists and Engineers (AKCSE)|8|club|AKCSE
ssmu-the-mcgill-chapter-of-the-chinese-psychology-student-association|The McGill Chapter of the Chinese Psychology Student Association|8|club
ssmu-the-mcgill-savoy-society|The McGill Savoy Society|4|club
ssmu-the-mcgill-student-chapter-of-fashion-revolution|The McGill Student Chapter of Fashion Revolution|4|club
ssmu-the-meditation-club|The Meditation Club|5|club
ssmu-the-refugee-centre-mcgill-chapter|The Refugee Centre McGill Chapter|2|club
ssmu-the-rennet|The Rennet|6|club
ssmu-the-sustainable-fashion-podcast-club|The Sustainable Fashion Podcast Club|2|club
ssmu-the-womens-network-mcgill|The Women’s Network McGill|8|club
ssmu-orphan-sponsorship-program|Through Their Eyes|2|club
ssmu-tonal-ecstacy-a-cappella|Tonal Ecstasy A Cappella|4|club
ssmu-tunisian-student-society|Tunisian Student Society|10|club
ssmu-turkish-students-society-of-mcgill-university-tssmu|Turkish Students Society of McGill University (TSSMU)|10|club|TSSMU
ssmu-urban-groove-dance-project|United Groove (formerly Urban Groove)|4|club|Urban Groove
recreation-university-squash-club-usc-recreational|University Squash Club (USC-Recreational)|14|club
ssmu-mcgill-chapter-of-women-in-international-security|Women in International Security Association of McGill University|8|club
ssmu-ssmu-women-in-tech|Women in Tech (WIT)|8|club|WIT
ssmu-womens-health-advocacy-club|Women’s Health Advocacy Club|5|club
ssmu-youth-outreach-program|Youth Outreach Program (YOP)|3|club|Youth Outreach Program|YOP
''';
