<map version="0.9.0">
<!--To view this file, download free mind mapping software Freeplane from http://freeplane.sourceforge.net -->
<node ID="ID_1378351314" CREATED="1343246727593" MODIFIED="1343247768120">
<richcontent TYPE="NODE">
<html>
  <head>
    
  </head>
  <body>
    <p>
      Development
    </p>
    <p>
      Checklists
    </p>
  </body>
</html></richcontent>
<hook NAME="MapStyle" max_node_width="600"/>
<node TEXT="Adding an entity attribute" FOLDED="true" POSITION="right" ID="ID_30726038" CREATED="1343246737341" MODIFIED="1343246746379">
<node TEXT="Data type" ID="ID_88865265" CREATED="1343246818415" MODIFIED="1343246820149">
<node TEXT="Add new data type (e.g., enum(n) type), if needed" ID="ID_1628477994" CREATED="1343246777383" MODIFIED="1343246792556"/>
</node>
<node TEXT="Schema" ID="ID_201879660" CREATED="1343246825401" MODIFIED="1343246829621">
<node TEXT="Add new column to relevant scenariodb(n) table" ID="ID_1687720079" CREATED="1343246793663" MODIFIED="1343246837902"/>
</node>
<node TEXT="GUI Views" ID="ID_52805764" CREATED="1343246846538" MODIFIED="1343246849015">
<node TEXT="Add new column to relevant GUI views" ID="ID_498201800" CREATED="1343246849617" MODIFIED="1343246858271"/>
</node>
<node TEXT="Mutators" ID="ID_246984085" CREATED="1343246870083" MODIFIED="1343246873776">
<node TEXT="Update entity mutators for new attribute" ID="ID_422764098" CREATED="1343246874131" MODIFIED="1343246885440"/>
</node>
<node TEXT="Orders" ID="ID_1502294059" CREATED="1343246886386" MODIFIED="1343246887503">
<node TEXT="Update entity orders for new attribute" ID="ID_67198273" CREATED="1343246887962" MODIFIED="1343246893535"/>
</node>
<node TEXT="Tests" ID="ID_1458031814" CREATED="1343252490174" MODIFIED="1343252491706">
<node TEXT="Update &quot;ted&quot; entity definitions" ID="ID_677048185" CREATED="1343252501374" MODIFIED="1343252517487"/>
<node TEXT="010-* tests" ID="ID_1114615723" CREATED="1343246904299" MODIFIED="1343246915127">
<node TEXT="Update mutator tests" ID="ID_1304694577" CREATED="1343246915450" MODIFIED="1343246931063"/>
</node>
<node TEXT="020-* tests" ID="ID_1828401706" CREATED="1343246920618" MODIFIED="1343246926190">
<node TEXT="Update order tests" ID="ID_1940496400" CREATED="1343246932346" MODIFIED="1343246935590"/>
</node>
<node TEXT="Verify that all Athena tests pass" ID="ID_1912844312" CREATED="1343250822966" MODIFIED="1343250828531"/>
</node>
<node TEXT="Browser" ID="ID_1942579226" CREATED="1343246967387" MODIFIED="1343246972680">
<node TEXT="Update the browser/browsers for this entity type" ID="ID_1415752999" CREATED="1343246972956" MODIFIED="1343246980216"/>
</node>
<node TEXT="Appserver" ID="ID_1333353120" CREATED="1343246982338" MODIFIED="1343246994330">
<node TEXT="Update the relevant appserver pages" ID="ID_1129041384" CREATED="1343246984788" MODIFIED="1343246990680"/>
</node>
<node TEXT="Help pages" ID="ID_502437366" CREATED="1343246996492" MODIFIED="1343246998881">
<node TEXT="Update the relevant help pages" ID="ID_1531533085" CREATED="1343246999324" MODIFIED="1343247005218"/>
<node TEXT="tab.help" ID="ID_1941006968" CREATED="1343252145358" MODIFIED="1343252175879">
<node TEXT="The browser tab(s)" ID="ID_1498633286" CREATED="1343252176697" MODIFIED="1343252180413"/>
</node>
<node TEXT="object_*.help" ID="ID_1854545082" CREATED="1343252158183" MODIFIED="1343252186364">
<node TEXT="The entity&apos;s object page, if any." ID="ID_1869418099" CREATED="1343252186656" MODIFIED="1343252194508"/>
</node>
<node TEXT="order_*.help" ID="ID_1295362261" CREATED="1343252195415" MODIFIED="1343252198413">
<node TEXT="The entity&apos;s order pages, if any." ID="ID_408374197" CREATED="1343252199056" MODIFIED="1343252205566"/>
</node>
</node>
</node>
<node TEXT="Defining a new tactic type" FOLDED="true" POSITION="right" ID="ID_1012865532" CREATED="1343318922846" MODIFIED="1343318934404">
<node TEXT="Determine the parameters; reuse the existing tactics table columns when appropriate" ID="ID_1045410495" CREATED="1343318953016" MODIFIED="1343319044216"/>
<node TEXT="Add new parameters" ID="ID_1863562007" CREATED="1343318957063" MODIFIED="1343318997822">
<node TEXT="Database schema" ID="ID_388596873" CREATED="1343319020474" MODIFIED="1343319026127">
<node TEXT="Add columns to tactics table" ID="ID_231236546" CREATED="1343319026618" MODIFIED="1343319036447"/>
</node>
<node TEXT="shared/tactics.tcl" ID="ID_1898704481" CREATED="1343318998185" MODIFIED="1343319098362">
<node TEXT="Add new parms to optparms" ID="ID_275005185" CREATED="1343319060452" MODIFIED="1343319066513"/>
<node TEXT="Update mutators" ID="ID_856943737" CREATED="1343319067395" MODIFIED="1343319071897"/>
</node>
<node TEXT="010-tactics.tcl" ID="ID_1169815907" CREATED="1343319779135" MODIFIED="1343319786588">
<node TEXT="Update" ID="ID_1275775442" CREATED="1343319786967" MODIFIED="1343319788604"/>
</node>
</node>
<node TEXT="Add shared/tactic_dummy.tcl" ID="ID_1669462533" CREATED="1343319079460" MODIFIED="1343319104330">
<node TEXT="Parallel to other tactics" ID="ID_770902164" CREATED="1343319104734" MODIFIED="1343319110363"/>
<node TEXT="Standard tactic subcommands" ID="ID_1341891367" CREATED="1343319870172" MODIFIED="1343319873873"/>
<node TEXT="CREATE and UPDATE orders" ID="ID_579251997" CREATED="1343319874284" MODIFIED="1343319881425"/>
</node>
<node TEXT="Add 010-tactic_dummy.tcl" ID="ID_1218999489" CREATED="1343319800481" MODIFIED="1343319817677">
<node TEXT="Test tactic subcommands" ID="ID_988112363" CREATED="1343319818120" MODIFIED="1343319825214"/>
</node>
<node TEXT="Add 010-TACTIC-DUMMY.tcl" ID="ID_1826871238" CREATED="1343319826560" MODIFIED="1343319840528">
<node TEXT="Test tactic orders" ID="ID_1005667835" CREATED="1343319841875" MODIFIED="1343319853120"/>
</node>
<node TEXT="Update help" ID="ID_1238282535" CREATED="1343844172211" MODIFIED="1343844176751">
<node TEXT="Add tactic object to object_tactic.help" ID="ID_739272604" CREATED="1343844177506" MODIFIED="1343844188829"/>
<node TEXT="Add order pages to order_tactic.help" ID="ID_1026057679" CREATED="1343844189218" MODIFIED="1343844195110"/>
</node>
</node>
<node TEXT="Defining a gofer::NUMBER rule" POSITION="right" ID="ID_691294663" CREATED="1383083935142" MODIFIED="1383083944430">
<node TEXT="Determine the rule&apos;s name and parameters" ID="ID_1295330900" CREATED="1383083963521" MODIFIED="1383083974534"/>
<node TEXT="Determine how to retrieve the desired number" ID="ID_292230656" CREATED="1383083975265" MODIFIED="1383083985574"/>
<node TEXT="In gofer_number.tcl" ID="ID_1658391915" CREATED="1383083945976" MODIFIED="1383084177319">
<node TEXT="Add a case for the rule and its parameters to the dynaform at the top of the file." ID="ID_1145251164" CREATED="1383083956216" MODIFIED="1383084004319"/>
<node TEXT="If in doubt, put it at the end." ID="ID_601355061" CREATED="1383084043244" MODIFIED="1383084049502"/>
<node TEXT="Add a [gofer rule] object for the new rule, parallel to the existing rules." ID="ID_1029822361" CREATED="1383084005434" MODIFIED="1383084038617"/>
<node TEXT="The rule objects should be in the same order as the dynaform cases." ID="ID_491007698" CREATED="1383084050924" MODIFIED="1383084077338"/>
<node TEXT="Use the helpers from gofer.tcl and gofer_helpers.tcl as appropriate." ID="ID_403896074" CREATED="1383084101742" MODIFIED="1383084115236"/>
<node TEXT="Add new helpers if appropriate" ID="ID_1705721843" CREATED="1383084133000" MODIFIED="1383084136636"/>
<node TEXT="The narrative should be the matching execution function." ID="ID_1807602901" CREATED="1383858247051" MODIFIED="1383858266157"/>
<node TEXT="The rule should always returns a numeric result when called with valid parameters." ID="ID_248264871" CREATED="1383858365566" MODIFIED="1383858384779"/>
<node TEXT="Often, this means returning 0.0 or some similar value when the [sim state] is PREP." ID="ID_1421748599" CREATED="1383858386271" MODIFIED="1383858410827"/>
</node>
<node TEXT="In executive.tcl" ID="ID_1187749632" CREATED="1383858272659" MODIFIED="1383858284985">
<node TEXT="Add the matching executive function, in parallel to the existing ones." ID="ID_459111863" CREATED="1383858285852" MODIFIED="1383858298840"/>
<node TEXT="The function should rely on the gofer for all parameter validation." ID="ID_1759732480" CREATED="1383858299228" MODIFIED="1383858313042"/>
</node>
<node TEXT="Test the gofer rule interactively" ID="ID_21552464" CREATED="1383084261654" MODIFIED="1383084268651">
<node TEXT="Use the COMPARE condition in a scenario." ID="ID_1930229849" CREATED="1383084268958" MODIFIED="1383084279371"/>
<node TEXT="Test the dynaform layout and text." ID="ID_1868858426" CREATED="1383084279887" MODIFIED="1383084289660"/>
<node TEXT="Spot check the behavior (i.e., no bgerrors)" ID="ID_1131690357" CREATED="1383084291047" MODIFIED="1383084328701"/>
</node>
<node TEXT="Test the executive function interactively using the [expr] command at the Athena CLI." ID="ID_1008762090" CREATED="1383858319077" MODIFIED="1383858336897"/>
<node TEXT="Code Review, if needed" ID="ID_1925898206" CREATED="1383084465246" MODIFIED="1383084470556"/>
<node TEXT="In 010-gofer_number.test" ID="ID_1062198334" CREATED="1383084116927" MODIFIED="1383857955813">
<node TEXT="Add tests for the new rule, parallel to the existing rules." ID="ID_18635815" CREATED="1383084125927" MODIFIED="1383084148166"/>
<node TEXT="The rules should be in the same order as in gofer_number.tcl." ID="ID_658426211" CREATED="1383084148769" MODIFIED="1383084159230"/>
</node>
<node TEXT="In 010-gofer_helpers.test" ID="ID_1043928615" CREATED="1383084184162" MODIFIED="1383857963540">
<node TEXT="Add tests for any new or extended helpers." ID="ID_1980163295" CREATED="1383084191075" MODIFIED="1383084214252"/>
</node>
<node TEXT="In 030-function.test" ID="ID_1493838361" CREATED="1383858343485" MODIFIED="1383858352002">
<node TEXT="Add tests for the executive function." ID="ID_144214576" CREATED="1383858352382" MODIFIED="1383858358451"/>
</node>
<node TEXT="Run 010-gofer.test" ID="ID_1423632373" CREATED="1383084215946" MODIFIED="1383084233081">
<node TEXT="This verifies that the dynaform and rules are consistent." ID="ID_1743239617" CREATED="1383084234196" MODIFIED="1383084246905"/>
</node>
<node TEXT="In gofer.help" ID="ID_587268283" CREATED="1383084337609" MODIFIED="1383084357190">
<node TEXT="Add a page for the rule, parallel to the existing rules." ID="ID_479546257" CREATED="1383084357754" MODIFIED="1383084377023"/>
<node TEXT="The rules should be in the same order as in gofer_number.tcl." ID="ID_1240544135" CREATED="1383084377298" MODIFIED="1383084387952"/>
<node TEXT="Build the help and review it in the Detail Browser" ID="ID_857693444" CREATED="1383084388691" MODIFIED="1383084407825"/>
</node>
<node TEXT="Run &quot;athena_test all&quot;" ID="ID_752467800" CREATED="1383084410748" MODIFIED="1383084423553">
<node TEXT="Fix any problems." ID="ID_661967420" CREATED="1383084428437" MODIFIED="1383084431521"/>
<node TEXT="Update tests as needed" ID="ID_83381592" CREATED="1383084431965" MODIFIED="1383084436185"/>
</node>
</node>
</node>
</map>
