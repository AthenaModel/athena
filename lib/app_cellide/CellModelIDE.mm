<map version="0.9.0">
<!--To view this file, download free mind mapping software Freeplane from http://freeplane.sourceforge.net -->
<node TEXT="Cell Model IDE" ID="ID_1374927924" CREATED="1341603422432" MODIFIED="1345745265690">
<hook NAME="MapStyle" max_node_width="600"/>
<node TEXT="cellmodel(5) IDE" POSITION="right" ID="ID_1252001141" CREATED="1345235120861" MODIFIED="1345235136259">
<icon BUILTIN="idea"/>
</node>
<node TEXT="To Do" POSITION="left" ID="ID_895967303" CREATED="1345670881486" MODIFIED="1345670883890">
<node TEXT="Executive" ID="ID_772441423" CREATED="1345671868602" MODIFIED="1345671894958"/>
<node TEXT="CLI in .main" ID="ID_1431289223" CREATED="1345671895633" MODIFIED="1345671898685"/>
<node TEXT="Tabs in .main, including Detail Browser" ID="ID_498831741" CREATED="1345671918480" MODIFIED="1345671929228"/>
</node>
<node TEXT="HTML" FOLDED="true" POSITION="left" ID="ID_766569321" CREATED="1345243822968" MODIFIED="1345243824542">
<node TEXT="appserver display of expanded model, with links from cell to cell" ID="ID_640097853" CREATED="1345243824929" MODIFIED="1345243836782"/>
</node>
<node TEXT="Tabbed window" FOLDED="true" POSITION="left" ID="ID_1639094298" CREATED="1345242239808" MODIFIED="1345242245069">
<node TEXT="Cell Model tab" ID="ID_424385705" CREATED="1345242586052" MODIFIED="1345242589593"/>
<node TEXT="Sheets tab" ID="ID_1492455643" CREATED="1345242590077" MODIFIED="1345242592297"/>
<node TEXT="Other tabs for running and browsing the contents." ID="ID_1776415332" CREATED="1345242601749" MODIFIED="1345242612626"/>
</node>
<node TEXT="Projects" POSITION="left" ID="ID_595781084" CREATED="1345242245847" MODIFIED="1345242273259">
<node TEXT="Project file is an SQLite file" ID="ID_378604453" CREATED="1345242253007" MODIFIED="1345242258611"/>
<node TEXT="Need project module" FOLDED="true" ID="ID_227721713" CREATED="1345242258910" MODIFIED="1345242290289">
<node TEXT="Like scenario module in app_sim" ID="ID_1877568682" CREATED="1345242291941" MODIFIED="1345242297177"/>
</node>
<node TEXT="Contains" ID="ID_1849644612" CREATED="1345242302923" MODIFIED="1345242321888">
<node TEXT="Any number of cell models" ID="ID_1841986765" CREATED="1345242322627" MODIFIED="1345584526711"/>
<node TEXT="Each cell model has zero or more sheets" ID="ID_41975989" CREATED="1345242334404" MODIFIED="1345584545511"/>
</node>
<node TEXT="The entire project is loaded and saved as one." ID="ID_473569592" CREATED="1345242379070" MODIFIED="1345242385907"/>
</node>
<node TEXT="Infrastructure" FOLDED="true" POSITION="left" ID="ID_1772245955" CREATED="1345584587507" MODIFIED="1345584590497">
<node TEXT="Editor Widget" ID="ID_758488912" CREATED="1345235139334" MODIFIED="1345242238924">
<node TEXT="Based on ctext" ID="ID_1941842186" CREATED="1345235142454" MODIFIED="1345241740864">
<icon BUILTIN="button_ok"/>
</node>
<node TEXT="cellmodel(5) syntax highlighting" ID="ID_1261974155" CREATED="1345235149823" MODIFIED="1345241740866">
<icon BUILTIN="button_ok"/>
</node>
<node TEXT="Syntax highlighting packages" ID="ID_426787954" CREATED="1345235172527" MODIFIED="1345241740865">
<icon BUILTIN="button_ok"/>
</node>
<node TEXT="snit wrapper for ctext" ID="ID_702889873" CREATED="1345235178943" MODIFIED="1345241740865">
<icon BUILTIN="button_ok"/>
</node>
<node TEXT="indent is 4 spaces" ID="ID_647278443" CREATED="1345235203354" MODIFIED="1345241740865">
<icon BUILTIN="button_ok"/>
</node>
</node>
<node TEXT="Scenario Manager" ID="ID_1899824140" CREATED="1345584741073" MODIFIED="1345584747414">
<node TEXT="Manages RDB, etc." ID="ID_640005286" CREATED="1345584748593" MODIFIED="1345584755565"/>
</node>
<node TEXT="appserver" ID="ID_1500688260" CREATED="1345584608389" MODIFIED="1345588560147">
<icon BUILTIN="button_ok"/>
</node>
<node TEXT="Project Tree" ID="ID_1701660678" CREATED="1345584635862" MODIFIED="1345584638459">
<node TEXT="Uses linktree" ID="ID_527342596" CREATED="1345584638798" MODIFIED="1345584662851"/>
</node>
<node TEXT="Tab manager" ID="ID_1940770079" CREATED="1345584610821" MODIFIED="1345584671260">
<node TEXT="Edit tab" ID="ID_1316333411" CREATED="1345584671687" MODIFIED="1345584674276">
<node TEXT="Edits item selected in project tree" ID="ID_1792660133" CREATED="1345584674704" MODIFIED="1345584681052"/>
<node TEXT="Content varies depending on type of item" ID="ID_224778892" CREATED="1345584684264" MODIFIED="1345584697798"/>
</node>
</node>
</node>
<node TEXT="Architectures" FOLDED="true" POSITION="right" ID="ID_474804534" CREATED="1345747973710" MODIFIED="1345747981198">
<node TEXT="SQLite Project File" ID="ID_1828977772" CREATED="1345744482457" MODIFIED="1345744489773">
<node TEXT="Document format for athena_cell" ID="ID_49291887" CREATED="1345744525926" MODIFIED="1345744553881"/>
<node TEXT="SQLite database" ID="ID_138103534" CREATED="1345744558795" MODIFIED="1345744568654"/>
<node TEXT="Contains one or more cell models with attached cmsheet scripts, plus metadata" ID="ID_553781791" CREATED="1345744490202" MODIFIED="1345744574309"/>
<node TEXT="Advantages" ID="ID_1511536629" CREATED="1345744575191" MODIFIED="1345744577078">
<node TEXT="Related cell model information is stored in a single file." ID="ID_1019317089" CREATED="1345744577632" MODIFIED="1345744606757"/>
<node TEXT="It sounds fun to do." ID="ID_515556618" CREATED="1345744608840" MODIFIED="1345744612880"/>
</node>
<node TEXT="Disadvantages" ID="ID_1384265990" CREATED="1345744615181" MODIFIED="1345744618769">
<node TEXT="SQLite DB" ID="ID_1159770083" CREATED="1345744619417" MODIFIED="1345744737088">
<node TEXT="The project file would be part of the Athena source code." ID="ID_1289850427" CREATED="1345744737548" MODIFIED="1345744761869"/>
<node TEXT="Athena.exe can&apos;t access SQLite DBs that are stored within athena.exe." ID="ID_1493091599" CREATED="1345744762267" MODIFIED="1345744778428"/>
<node TEXT="Adds complexity; and is probably not worth it." ID="ID_570991490" CREATED="1345744779138" MODIFIED="1345744786330"/>
<node TEXT="But, could make &quot;athena cell -export&quot; export the current files; do this in the build process." ID="ID_498352710" CREATED="1345747309841" MODIFIED="1345747357781">
<icon BUILTIN="ksmiletris"/>
</node>
</node>
<node TEXT="User interactions" ID="ID_811505725" CREATED="1345744794294" MODIFIED="1345744797975">
<node TEXT="I don&apos;t completely understand how a user should interact with the application." ID="ID_1786107448" CREATED="1345744798248" MODIFIED="1345744843005"/>
<node TEXT="It&apos;s nice to edit a file and have the choice to explicitly save or not." ID="ID_759691481" CREATED="1345744850992" MODIFIED="1345744887199"/>
<node TEXT="But here, we have two &quot;files&quot;:  The project as a whole, and the individual script." ID="ID_1039370325" CREATED="1345744942696" MODIFIED="1345744959607"/>
<node TEXT="How do we distinguish between saving or not saving the individual script when they save the project?" ID="ID_1142528317" CREATED="1345745002429" MODIFIED="1345745025174"/>
<node TEXT="Could use Wiki-style editing." ID="ID_197209738" CREATED="1345747342383" MODIFIED="1345747354661">
<icon BUILTIN="ksmiletris"/>
</node>
</node>
</node>
</node>
<node TEXT="Project Metadata File" ID="ID_1162708421" CREATED="1345745040680" MODIFIED="1345745049880">
<node TEXT="" ID="ID_1904145098" CREATED="1345745073038" MODIFIED="1345745075440">
<icon BUILTIN="idea"/>
<node TEXT="Most IDEs keep the source files on the disk." ID="ID_466837258" CREATED="1345745076181" MODIFIED="1345745084746"/>
<node TEXT="The project file stores metadata about the project, including which files are included." ID="ID_1107322630" CREATED="1345745085112" MODIFIED="1345745103068"/>
<node TEXT="This allows the project to be built, etc." ID="ID_84475221" CREATED="1345745103450" MODIFIED="1345745112904"/>
</node>
<node TEXT="Advantages" ID="ID_832582211" CREATED="1345745119229" MODIFIED="1345745121616">
<node TEXT="Project file doesn&apos;t get delivered, so can safely be SQLite." ID="ID_697338733" CREATED="1345745121983" MODIFIED="1345745133480"/>
<node TEXT="Allows a number of artifacts to be grouped." ID="ID_914884599" CREATED="1345745136779" MODIFIED="1345745148448"/>
</node>
<node TEXT="Disadvantages" ID="ID_571507720" CREATED="1345745149423" MODIFIED="1345745151810">
<node TEXT="I&apos;ve not often used IDEs of this sort; I don&apos;t have a good gut feel for the interaction patterns." ID="ID_1776191836" CREATED="1345745152255" MODIFIED="1345745220910"/>
<node TEXT="How do you synchronize the project with the files on the disk?" ID="ID_27709652" CREATED="1345745221370" MODIFIED="1345745237360"/>
<node TEXT="Not clear that there&apos;s much metadata beyond the scripts." ID="ID_1762468103" CREATED="1345745241689" MODIFIED="1345745255558"/>
</node>
</node>
<node TEXT="Wiki editing" ID="ID_1290173802" CREATED="1345744887925" MODIFIED="1345744890436">
<node TEXT="Do everything in the detail browser" ID="ID_1119223350" CREATED="1345744890663" MODIFIED="1345744897745"/>
<node TEXT="Displays an HTML page about the model, with an edit button." ID="ID_1862478870" CREATED="1345744900202" MODIFIED="1345744911450"/>
<node TEXT="Takes you to a different page, with an editor window in it, as in a Wiki." ID="ID_482484995" CREATED="1345744911832" MODIFIED="1345744932159"/>
<node TEXT="Modal!" ID="ID_1204389036" CREATED="1345744932588" MODIFIED="1345744937190"/>
</node>
</node>
<node TEXT="Simplest Thing" FOLDED="true" POSITION="right" ID="ID_1079068103" CREATED="1345747988054" MODIFIED="1345747991596">
<node TEXT="What&apos;s the simplest thing that I can do that would be somewhat useful?" ID="ID_1092497164" CREATED="1345747992134" MODIFIED="1345748021252">
<icon BUILTIN="idea"/>
</node>
<node TEXT="Required Features" ID="ID_655518136" CREATED="1345748152605" MODIFIED="1345748163220">
<node TEXT="A tool" ID="ID_1373841446" CREATED="1345748022648" MODIFIED="1346084871007">
<icon BUILTIN="button_ok"/>
</node>
<node TEXT="that can edit and save one cellmodel at a time" ID="ID_592308092" CREATED="1345748026337" MODIFIED="1346084871009">
<icon BUILTIN="button_ok"/>
</node>
<node TEXT="that can validate the cell model source code, taking me to the line that is in error" ID="ID_22106532" CREATED="1345748031914" MODIFIED="1346084871008">
<icon BUILTIN="button_ok"/>
</node>
<node TEXT="that can let me explore the content of valid cell models" ID="ID_248058343" CREATED="1345748057116" MODIFIED="1346882637943">
<icon BUILTIN="button_ok"/>
</node>
<node TEXT="that can help me run the model and examine the root of runtime errors" ID="ID_1122750597" CREATED="1345748117816" MODIFIED="1345748134883"/>
<node TEXT="that can let me import and edit the input values, distinct from those in the cellmodel(5) script" ID="ID_37886187" CREATED="1345748199639" MODIFIED="1345748216581"/>
</node>
<node TEXT="Features Not Required" ID="ID_359409862" CREATED="1345748163852" MODIFIED="1345748169499">
<node TEXT="Project file" ID="ID_1251994346" CREATED="1345748169819" MODIFIED="1345748171520"/>
<node TEXT="SQLite storage" ID="ID_935404100" CREATED="1345748171839" MODIFIED="1345748176488"/>
<node TEXT="cmsheet scripts (which don&apos;t exist yet anyway)" ID="ID_1919353422" CREATED="1345748176886" MODIFIED="1345748187447"/>
</node>
<node TEXT="Architecture" ID="ID_89524609" CREATED="1345748227735" MODIFIED="1345748229872">
<node TEXT="Window with" ID="ID_369292037" CREATED="1345748230270" MODIFIED="1345748238397">
<node TEXT="Main menu" ID="ID_973373937" CREATED="1345748238733" MODIFIED="1345748240667">
<node TEXT="Standard document-centric menus" ID="ID_759239644" CREATED="1345748301040" MODIFIED="1345748336639"/>
</node>
<node TEXT="Toolbar" ID="ID_314621180" CREATED="1345748241081" MODIFIED="1345748243467"/>
<node TEXT="Script tab, for editing cellmodel(5) scripts" ID="ID_390534167" CREATED="1345748243850" MODIFIED="1345748265237"/>
<node TEXT="Detail browser tab, for exploring the cell model" ID="ID_179385037" CREATED="1345748267024" MODIFIED="1345748278474"/>
<node TEXT="Tabs for running the cell model, and editing inputs" ID="ID_1643232303" CREATED="1345748280229" MODIFIED="1345748287701">
<node TEXT="Possibly embedded in detail browser tab" ID="ID_543064630" CREATED="1345748288115" MODIFIED="1345748299815"/>
</node>
</node>
<node TEXT="cmscript module" FOLDED="true" ID="ID_1465916911" CREATED="1345748397370" MODIFIED="1345748399804">
<node TEXT="For managing the currently loaded cellmodel(5) script" ID="ID_1759192769" CREATED="1345748400077" MODIFIED="1345748408064"/>
<node TEXT="Associated with the editor window" ID="ID_1722054661" CREATED="1345748409008" MODIFIED="1345748417494"/>
<node TEXT="Replaced project/projectdb." ID="ID_553789273" CREATED="1345748422923" MODIFIED="1345748428570"/>
</node>
</node>
</node>
<node TEXT="Snapshots" POSITION="right" ID="ID_1346380049" CREATED="1347471655190" MODIFIED="1347471702949">
<node TEXT="" ID="ID_925766383" CREATED="1347471718596" MODIFIED="1347471722605">
<icon BUILTIN="idea"/>
<node TEXT="A snapshot is a set of cell names and values." ID="ID_261236904" CREATED="1347471659856" MODIFIED="1347471713118"/>
<node TEXT="Can be partial or complete" ID="ID_1132700068" CREATED="1347471761443" MODIFIED="1347472251308">
<node TEXT="Partial is relative to the cellmodel&apos;s initial values" ID="ID_1844377334" CREATED="1347471732005" MODIFIED="1347471786849"/>
<node TEXT="Complete is all cells and values" ID="ID_1095665370" CREATED="1347471787236" MODIFIED="1347471791183"/>
</node>
<node TEXT="Each has a distinct URL" ID="ID_298496632" CREATED="1347472295818" MODIFIED="1347472300842"/>
</node>
<node TEXT="Kinds of Snapshot" ID="ID_166813697" CREATED="1347471713689" MODIFIED="1347472161810">
<node TEXT="Aliases" ID="ID_1714378054" CREATED="1347472164101" MODIFIED="1347472172241">
<node TEXT="&quot;Model&quot;" ID="ID_1924670570" CREATED="1347471802898" MODIFIED="1347477139820">
<node TEXT="Initial values from cellmodel text." ID="ID_1617065530" CREATED="1347471806419" MODIFIED="1347471816337"/>
</node>
<node TEXT="&quot;Current&quot;" ID="ID_1808419671" CREATED="1347471817162" MODIFIED="1347472077632">
<node TEXT="Whatever is currently in the cellmodel(n) object" ID="ID_966196162" CREATED="1347471819099" MODIFIED="1347471831344"/>
</node>
<node TEXT="&quot;Last Solution&quot;" ID="ID_988085033" CREATED="1347471832771" MODIFIED="1347472081319">
<node TEXT="The output of the last &quot;solve&quot; operation" ID="ID_1806078333" CREATED="1347471840084" MODIFIED="1347471851361"/>
<node TEXT="Alias to &quot;Solution &lt;timestamp&gt;&quot; for the most recent successful solution" ID="ID_276396676" CREATED="1347472084516" MODIFIED="1347472096281"/>
</node>
</node>
<node TEXT="Auto-Generated" ID="ID_1638953415" CREATED="1347472172646" MODIFIED="1347472176163">
<node TEXT="Solutions" ID="ID_885318786" CREATED="1347471901045" MODIFIED="1347471914369">
<node TEXT="When the model is solved, the solution is saved as a snapshot." ID="ID_1671418431" CREATED="1347471915013" MODIFIED="1347471928043"/>
<node TEXT="&quot;Solution &lt;timestamp&gt;&quot;" ID="ID_382233738" CREATED="1347471949847" MODIFIED="1347471960964"/>
<node TEXT="Might be linked to information about the solution specs" ID="ID_846647701" CREATED="1347471961984" MODIFIED="1347471969076"/>
</node>
<node TEXT="Failures" ID="ID_532760745" CREATED="1347471929078" MODIFIED="1347472027982">
<node TEXT="If the &quot;solve&quot; operation fails, save the resulting cell values as a &quot;failure&quot; snapshot instead of a solution snapshot" ID="ID_1270954214" CREATED="1347471971328" MODIFIED="1347472007958"/>
<node TEXT="&quot;Failure &lt;timestamp&gt;&quot;" ID="ID_1628951751" CREATED="1347472008778" MODIFIED="1347472017574"/>
<node TEXT="Might be linked to failure details." ID="ID_592533529" CREATED="1347472018026" MODIFIED="1347472022399"/>
</node>
<node TEXT="Iterations" ID="ID_1860376912" CREATED="1347472028795" MODIFIED="1347472033215">
<node TEXT="Save the iterations associated with the last solution." ID="ID_1700342143" CREATED="1347472033730" MODIFIED="1347472058900"/>
<node TEXT="&quot;Iteration &lt;n&gt;" ID="ID_1037586060" CREATED="1347472059235" MODIFIED="1347472067659"/>
<node TEXT="Wouldn&apos;t usually use these as basis for solution." ID="ID_186529754" CREATED="1347472069087" MODIFIED="1347472137075"/>
</node>
</node>
<node TEXT="Manually Created" ID="ID_336826599" CREATED="1347472177101" MODIFIED="1347472184651">
<node TEXT="Imports" ID="ID_781957104" CREATED="1347471859850" MODIFIED="1347471864764">
<node TEXT="Snapshots can be imported; the cgedebug.txt file from athena_sim is a snapshot." ID="ID_1349660695" CREATED="1347471865240" MODIFIED="1347471884218"/>
<node TEXT="Imported snapshots are called &quot;Imported &lt;timestamp&quot;" ID="ID_433977784" CREATED="1347471884733" MODIFIED="1347471899227"/>
</node>
<node TEXT="Hand Edits" ID="ID_933616425" CREATED="1347472214271" MODIFIED="1347472216835">
<node TEXT="&quot;User Edit &lt;timestamp&gt;" ID="ID_842888867" CREATED="1347472222047" MODIFIED="1347472232970"/>
</node>
</node>
</node>
<node TEXT="Uses for snapshots" ID="ID_815072536" CREATED="1347472255344" MODIFIED="1347472258548">
<node TEXT="Basis for &quot;solve&quot; operation; user specifies the snapshot to use as the initial values." ID="ID_1681002679" CREATED="1347472258983" MODIFIED="1347472278229"/>
<node TEXT="Can be exported" ID="ID_1529460766" CREATED="1347472278767" MODIFIED="1347472282355"/>
<node TEXT="Can be compared" ID="ID_918977824" CREATED="1347472282784" MODIFIED="1347472290725">
<node TEXT="E.g., run three different ways, compare the last three solutions" ID="ID_1242963678" CREATED="1347472313296" MODIFIED="1347472327249"/>
</node>
</node>
<node TEXT="Interaction Patterns" ID="ID_813708611" CREATED="1347472336819" MODIFIED="1347472340704">
<node TEXT="Snapshots are not saved by default; they are an artifact of the current session." ID="ID_24609613" CREATED="1347472341055" MODIFIED="1347472361226"/>
<node TEXT="User can export snapshots to disk if desired, and import them later." ID="ID_228716774" CREATED="1347472362367" MODIFIED="1347472380190"/>
<node TEXT="Most snapshots are saved automatically, as a byproduct of normal operation." ID="ID_1525500129" CREATED="1347472382545" MODIFIED="1347472395068"/>
</node>
</node>
<node TEXT="Next" POSITION="right" ID="ID_1459946860" CREATED="1345760892431" MODIFIED="1347471654901">
<node TEXT="Need a ::cmscript &lt;CheckState&gt; event, to trigger statecontrollers" ID="ID_331373726" CREATED="1347574831036" MODIFIED="1347574870839"/>
</node>
</node>
</map>
