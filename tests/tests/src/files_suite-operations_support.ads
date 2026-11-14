with Files.Desktop_Applications;
with Files.Model;
with Files.Operations;
with Files.Settings;
with Files.Types;

--  Helpers shared by the operation test sections (Files_Suite.Operations,
--  Transfer, Recovery, History, Trash, Search, Thumbnails, Archives, Info,
--  Names, Refresh and Open_Actions): fixtures, waits on background work, and
--  the names no host accepts.
package Files_Suite.Operations_Support is

   --  Path's permission bits, asserting the host reports them.
   --
   --  @param Path Entry whose mode to read.
   --  @return The owner, group and other bits of Path (below 8#1000#).
   function Mode_Of (Path : String) return Natural;

   --  The result of an operation once it is finished: a paste execution it
   --  left running is driven to its end first.
   --
   --  @param Model Window model the operation ran in.
   --  @param Settings Settings the operation runs with.
   --  @param Started The result the operation returned when it was started.
   --  @return Started, or the result of the finished paste execution.
   function Complete_Operation
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Started  : Files.Operations.Operation_Result) return Files.Operations.Operation_Result;

   --  Bring the selected item's details in the way a window does, off the
   --  UI thread: asked of the reader and polled until read.
   --
   --  @param Model Window model whose selected item to read.
   procedure Await_Item_Details (Model : in out Files.Model.Window_Model);

   --  Make Directory read-only and say whether that refuses a new entry: as
   --  POSIX root a create still succeeds and a refused write has nothing to
   --  observe. On Windows the mode is a protected DACL, which binds an
   --  elevated process too, so being elevated is no reason to give up there.
   --
   --  @param Directory Existing directory to lock.
   --  @return True when a file can no longer be created in Directory.
   function Lock_Directory (Directory : String) return Boolean;

   --  Give Directory its owner's write access back.
   --
   --  @param Directory Directory Lock_Directory locked.
   procedure Unlock_Directory (Directory : String);

   --  Saves XDG_DATA_HOME, HOME and FILES_TRASH_BACKEND, resets Root and the
   --  XDG trash fixture, runs Check, removes the trash fixtures, and restores
   --  the environment (also when Check raises).
   --
   --  @param Check The checks to run in the trash environment.
   procedure With_Trash_Environment (Check : not null access procedure);

   --  Info-pane detail text as the renderer composes it: Key's pattern with
   --  {Name} filled in.
   --
   --  @param Key Catalog key of the detail's pattern.
   --  @param Name Placeholder name in the pattern.
   --  @param Value Text the placeholder is filled with.
   --  @return The composed detail text.
   function Detail_Value (Key : String; Name : String; Value : String) return String;

   --  Detail_Value with the value itself looked up in the localization
   --  catalog.
   --
   --  @param Key Catalog key of the detail's pattern.
   --  @param Name Placeholder name in the pattern.
   --  @param Value_Key Catalog key of the value filled in.
   --  @return The composed detail text.
   function Detail_Localized_Value (Key : String; Name : String; Value_Key : String) return String;

   --  A line-count detail followed by the localized encoding detail.
   --
   --  @param Key Catalog key of the line-count pattern.
   --  @param Lines The line count, as text.
   --  @param Encoding_Key Catalog key of the encoding's name.
   --  @return The composed detail text.
   function Detail_Lines_Encoding (Key : String; Lines : String; Encoding_Key : String) return String;

   --  Write the info-pane metadata fixtures (text, source, office, PDF, PNG,
   --  JPEG) into Root.
   procedure Write_Info_Metadata_Fixtures;

   --  Saves the XDG and locale variables, resets Root, writes the
   --  desktop-entry fixture under it, points the XDG/locale variables at it,
   --  runs Check, and restores the environment (also when Check raises).
   --
   --  @param Check The checks to run against the fixture.
   procedure With_Desktop_Application_Fixture (Check : not null access procedure);

   --  The application named Name, or one with every field empty.
   --
   --  @param Apps Discovered applications.
   --  @param Name Name of the application to find.
   --  @return The application named Name, or an empty one.
   function Find_Application
     (Apps : Files.Desktop_Applications.Application_Vectors.Vector;
      Name : String)
      return Files.Desktop_Applications.Application;

   --  Runs this executable's abandon-transport crash fixture, which reports
   --  the transport it left behind in the file Report; Path receives that
   --  pathname.
   --
   --  @param Report File the fixture reports its transport in.
   --  @param Path The abandoned transport's pathname.
   procedure Create_Abandoned_Transport (Report : String; Path : out Files.Types.UString);

   --  A name with a NUL in it, which no host accepts; shared, like the
   --  names after it, by the create and rename checks.
   --
   --  @return The name.
   function Nul_Name return String;

   --  A name with a tab in it, which no host accepts.
   --
   --  @return The name.
   function Tab_Name return String;

   --  A name with a raw C1 control byte in it, which no host accepts.
   --
   --  @return The name.
   function C1_Name return String;

   --  A name with a UTF-8 encoded C1 control in it, which no host accepts.
   --
   --  @return The name.
   function Encoded_C1_Name return String;

   --  A name with a truncated UTF-8 sequence in it, which no host accepts.
   --
   --  @return The name.
   function Truncated_UTF8_Name return String;

   --  A name with an overlong UTF-8 sequence in it, which no host accepts.
   --
   --  @return The name.
   function Overlong_UTF8_Name return String;

   --  A no-break space, as the text field enters it.
   --
   --  @return The UTF-8 bytes of U+00A0.
   function NBSP_Name return String;

   --  An ideographic space, as the text field enters it.
   --
   --  @return The UTF-8 bytes of U+3000.
   function Ideographic_Space_Name return String;

   --  A name ending in a no-break space.
   --
   --  @return The name.
   function Trailing_NBSP_Name return String;

   --  A name ending in an ideographic space.
   --
   --  @return The name.
   function Trailing_Ideographic_Name return String;

   --  Collect the model's background read the way the window does, asserting
   --  it completes.
   --
   --  @param Model Window model whose read to collect.
   --  @param Settings Settings the read applies with.
   --  @param Applied Whether the read replaced the listing.
   procedure Await_View
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Applied  : out Boolean);

   --  Await_View, when whether the read replaced the listing does not matter.
   --
   --  @param Model Window model whose read to collect.
   --  @param Settings Settings the read applies with.
   procedure Await_View (Model : in out Files.Model.Window_Model; Settings : Files.Settings.Settings_Model);

   --  Wait for the model's background read to finish its snapshot (not yet
   --  applied), asserting it was not cancelled.
   --
   --  @param Model Window model whose read to wait for.
   --  @param What What the assertion reports.
   procedure Await_Refresh_Ready (Model : Files.Model.Window_Model; What : String);

   --  Collect the model's background read the way the window does, asserting
   --  it ended and whether it replaced the listing.
   --
   --  @param Model Window model whose read to collect.
   --  @param Settings Settings the read applies with.
   --  @param Expected Whether the read should replace the listing.
   --  @param What What the assertions report.
   procedure Await_Refresh_Applied
     (Model    : in out Files.Model.Window_Model;
      Settings : in out Files.Settings.Settings_Model;
      Expected : Boolean;
      What     : String);

   --  Path's permission bits as the host reports them, asserting it does.
   --
   --  @param Path Entry whose mode to read.
   --  @return The permission bits of Path, special bits included.
   function Metadata_Mode_Of (Path : String) return Natural;

   --  Whether only Path's owner can reach it.
   --
   --  @param Path Entry to check.
   --  @return True when nobody but the owner has access to Path.
   function Is_Owner_Only (Path : String) return Boolean;

   --  Confirm the destination picker through the real interaction reducer.
   --
   --  @param Model Window model whose picker to confirm.
   --  @param Settings Settings the reducer runs with.
   procedure Confirm_Pick
     (Model    : in out Files.Model.Window_Model;
      Settings : in out Files.Settings.Settings_Model);

   --  Drive a background operation to completion the way the UI does:
   --  its progress overlay is open, and it is collected without blocking.
   --
   --  @param Model Window model the operation runs in.
   --  @param Settings Settings the operation runs with.
   --  @param Step The operation's result, replaced by the finished one.
   procedure Finish_Background_Operation
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Step     : in out Files.Operations.Operation_Result);

end Files_Suite.Operations_Support;
