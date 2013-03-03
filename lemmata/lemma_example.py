from __future__ import division
import nltk, re, pprint
from lemmata_replacements import RegexpReplacer
replacer = RegexpReplacer()

#A simple test:
#raw = "feminae feminam puellarum puella"
#print raw
#replaced_lemmata = replacer.replace(raw)
#print replaced_lemmata
#tokens = nltk.word_tokenize(replaced_lemmata)
#print tokens

#raw = open("/home/kyle/NLTK/test_apps/cicero_comment.txt","r").read()
raw = 'Etsi tibi omnia suppetunt ea quae consequi ingenio aut usu homines aut diligentia possunt, tamen amore nostro non sum alienum arbitratus ad te perscribere ea quae mihi veniebant in mentem dies ac noctes de petitione tua cogitanti, non ut aliquid ex his novi addisceres, sed ut ea quae in re dispersa atque infinita viderentur esse ratione et distributione sub uno aspectu ponerentur. Quamquam plurimum natura valet, tamen videtur in paucorum mensium negotio posse simulatio naturam vincere. Civitas quae sit cogita, quid petas, qui sis. Prope cottidie tibi hoc ad forum descendenti meditandum est: "Novus sum, consulatum peto, Roma est." Nominis novitatem dicendi gloria maxime sublevabis. Semper ea res plurimum dignitatis habuit; non potest qui dignus habetur patronus consularium indignus consulatu putari. Quam ob rem quoniam ab hac laude proficisceris et quicquid es ex hoc es, ita paratus ad dicendum venito quasi in singulis causis iudicium de omni ingenio futurum sit. Eius facultatis adiumenta, quae tibi scio esse seposita, ut parata ac prompta sint cura, et saepe quae de Demosthenis studio et exercitatione scripsit Demetrius recordare. Deinde fac ut amicorum et multitudo et genera appareant; habes enim ea quae qui novi habuerunt? - omnis publicanos, totum fere equestrem ordinem, multa propria municipia, multos abs te defensos homines cuiusque ordinis, aliquot conlegia, praeterea studio dicendi conciliatos plurimos adulescentulos, cottidianam amicorum adsiduitatem et frequentiam. Haec cura ut teneas commonendo et rogando et omni ratione efficiendo ut intellegant qui debent tua causa, referendae gratiae, qui volunt, obligandi tui tempus sibi aliud nullum fore. Etiam hoc multum videtur adiuvare posse novum hominem, hominum nobilium voluntas et maxime consularium; prodest, quorum in locum ac numerum pervenire velis, ab iis ipsis illo loco ac numero dignum putari. Ii rogandi omnes sunt diligenter et ad eos adlegandum est persuadendumque est iis nos semper cum optimatibus de re publica sensisse, minime popularis fuisse; si quid locuti populariter videamur, id nos eo consilio fecisse ut nobis Cn. Pompeium adiungeremus, ut eum qui plurimum posset aut amicum in nostra petitione haberemus aut certe non adversarium. Praeterea adulescentis nobilis elabora ut habeas, vel ut teneas studiosos quos habes; multum dignitatis adferent. Plurimos habes; perfice ut sciant quantum in iis putes esse. Si adduxeris ut ii qui non nolunt cupiant, plurimum proderunt.'
replaced_lemmata = replacer.replace(raw)
print replaced_lemmata
