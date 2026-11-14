with Files.Operation_Results;
with Files.Extra_Info;
with Files.Items;
with Files.Commands;
with Files.Controller;
with Files.Events;
with Files.Model;
with Files.Rendering;
with Files.Settings;
with Guikit.Input;
with Files.Types;
with Files_Suite.Generic_Assert_Equal;

package Files_Suite.Support is

   --  Record that Test does not run here (a host without the feature it
   --  needs), so a skipped test is counted and named instead of passing in
   --  silence.
   --
   --  @param Test The test routine.
   --  @param Reason The condition that skips it.
   procedure Skip (Test : String; Reason : String);

   --  How many tests skipped so far.
   --
   --  @return The number of Skip calls.
   function Skip_Count return Natural;

   --  Whether a test skipped in this run for a reason.
   --
   --  @param Skip "Test: Reason", the test routine's name and the reason as
   --  passed to Skip -- the form a FILES_TEST_EXPECTED_SKIPS list uses.
   --  @return True when it skipped for that reason.
   function Has_Skipped (Skip : String) return Boolean;

   --  The skips of this run, each "Test: Reason" once, in the order they
   --  first happened.
   --
   --  @return Them.
   function Skips return Files.Types.String_Vectors.Vector;

   --  Assert Actual = Expected; a failure says both values, not only what
   --  was expected to hold.
   --
   --  @param Actual Observed value.
   --  @param Expected Wanted value.
   --  @param Message What the check is about.
   procedure Assert_Equal (Actual, Expected : Integer; Message : String);

   --  As Assert_Equal for sizes and byte counts.
   --
   --  @param Actual Observed value.
   --  @param Expected Wanted value.
   --  @param Message What the check is about.
   procedure Assert_Equal (Actual, Expected : Long_Long_Integer; Message : String);

   --  As Assert_Equal for text.
   --
   --  @param Actual Observed value.
   --  @param Expected Wanted value.
   --  @param Message What the check is about.
   procedure Assert_Equal (Actual, Expected : String; Message : String);

   --  As Assert_Equal for flags.
   --
   --  @param Actual Observed value.
   --  @param Expected Wanted value.
   --  @param Message What the check is about.
   procedure Assert_Equal (Actual, Expected : Boolean; Message : String);

   --  Assert that the rectangle at X, Y of Width by Height lies inside the
   --  one at Outer_X, Outer_Y of Outer_Width by Outer_Height. Each edge is
   --  its own check, so a failure names the edge that crosses ("left edge",
   --  "top edge", "right edge", "bottom edge") and both coordinates.
   --
   --  @param X Inner left.
   --  @param Y Inner top.
   --  @param Width Inner width.
   --  @param Height Inner height.
   --  @param Outer_X Outer left.
   --  @param Outer_Y Outer top.
   --  @param Outer_Width Outer width.
   --  @param Outer_Height Outer height.
   --  @param Message What the check is about.
   procedure Assert_Inside
     (X, Y, Width, Height                         : Integer;
      Outer_X, Outer_Y, Outer_Width, Outer_Height : Integer;
      Message                                     : String);

   --  Assert that the rectangle at X, Y of Width by Height is not empty and
   --  ends inside a Frame_Width by Frame_Height framebuffer. Each part is its
   --  own check ("width", "height", "right edge", "bottom edge").
   --
   --  @param X Left.
   --  @param Y Top.
   --  @param Width Width, which must be positive.
   --  @param Height Height, which must be positive.
   --  @param Frame_Width Framebuffer width.
   --  @param Frame_Height Framebuffer height.
   --  @param Message What the check is about.
   procedure Assert_Fits
     (X, Y, Width, Height       : Integer;
      Frame_Width, Frame_Height : Integer;
      Message                   : String);

   --  Assert Low <= Value <= High, one check per bound ("below" / "above"),
   --  each saying the value and the bound it crossed.
   --
   --  @param Value Observed value.
   --  @param Low Smallest allowed value.
   --  @param High Largest allowed value.
   --  @param Message What the check is about.
   procedure Assert_Between (Value, Low, High : Float; Message : String);

   --  Run a command through the controller's command entry
   --  (Files.Controller.Execute_Non_Settings_Command) with default settings, for a
   --  test that checks the command's effect on the model and not its result.
   --
   --  @param Id Command to run.
   --  @param Model Window model the command acts on.
   procedure Run_Command
     (Id    : Files.Commands.Command_Id;
      Model : in out Files.Model.Window_Model);

   --  Assert_Equal for the enumerations the suite compares most.
   procedure Assert_Equal is new Files_Suite.Generic_Assert_Equal (Files.Operation_Results.Operation_Status);
   procedure Assert_Equal is new Files_Suite.Generic_Assert_Equal (Files.Commands.Command_Id);
   procedure Assert_Equal is new Files_Suite.Generic_Assert_Equal (Files.Controller.Controller_Status);
   procedure Assert_Equal is new Files_Suite.Generic_Assert_Equal (Files.Types.Focus_Target);
   procedure Assert_Equal is new Files_Suite.Generic_Assert_Equal (Guikit.Input.Key_Code);
   procedure Assert_Equal is new Files_Suite.Generic_Assert_Equal (Files.Events.Input_Action_Kind);
   procedure Assert_Equal is new Files_Suite.Generic_Assert_Equal (Files.Types.Color_Label);
   procedure Assert_Equal is new Files_Suite.Generic_Assert_Equal (Files.Types.Account_Id);
   procedure Assert_Equal is new Files_Suite.Generic_Assert_Equal (Files.Types.View_Mode);
   procedure Assert_Equal is new Files_Suite.Generic_Assert_Equal (Files.Types.Detail_Column);
   procedure Assert_Equal is new Files_Suite.Generic_Assert_Equal (Files.Types.Sort_Field);
   procedure Assert_Equal is new Files_Suite.Generic_Assert_Equal (Files.Types.Group_Mode);

   --  Advance Model's paste execution one item at a time, as the frame loop
   --  does, until it ends, and assert it ended within the (scaled) poll
   --  limit. It is advanced at least once.
   --
   --  @param Model Window model whose paste execution to finish.
   --  @param Settings Settings the execution runs with.
   --  @return The result of the last advance.
   function Finish_Paste
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model) return Files.Operation_Results.Operation_Result;

   --  Drive every queued background folder-size walk of Model to completion,
   --  publishing each result as the frame loop's Poll_Window_Workers would,
   --  and assert they finished within the (scaled) poll limit.
   --
   --  @param Model Window model whose folder scans to drain.
   procedure Drain_Folder_Sizes (Model : in out Files.Model.Window_Model);

   --  The scheduler state of a process, from the third field of Linux's
   --  /proc/<pid>/stat: 'R' running, 'S' sleeping, 'T' stopped, 'Z' a zombie
   --  nobody has reaped, and so on.
   --
   --  @param Process_Id Process to look at.
   --  @return Its state letter, or ' ' when there is no such process (or no
   --  /proc to ask).
   function Process_State (Process_Id : Integer) return Character;

   --  The scratch directory every fixture builds under.
   --
   --  This is deliberately not a hardcoded "/tmp/...": on macOS /tmp is a
   --  symlink into /private, so the application's canonicalised paths never
   --  string-compare equal to a path spelled through it, and Windows has no /tmp
   --  at all. Test_Root resolves the platform's real temporary directory,
   --  following links, so a path built here matches the one the model reports.
   --  A function, not a constant: a spec-level constant cannot call into the
   --  body before that body is elaborated.
   --  @return the resolved, link-followed scratch directory path
   function Root return String;

   --  Does a mode bit decide what runs here? On POSIX, yes: chmod +x makes a file
   --  executable whatever it is called. Windows decides from the extension alone
   --  -- every ordinary file carries FILE_EXECUTE in its DACL, so the bit says
   --  nothing -- and GNAT.OS_Lib.Set_Executable is a no-op there.
   --
   --  So "run.sh, chmod +x" is an executable on POSIX and a plain file on Windows,
   --  and that is the product being right on both, not a gap. Tests that make a
   --  file executable branch on this; the ones that want an executable on Windows
   --  name it .bat.
   --  @return True on hosts where the executable mode bit governs execution
   function Honours_Executable_Bit return Boolean;

   --  A real executable that succeeds and does nothing, for tests that need an
   --  action to actually run. It is NOT /bin/true everywhere: macOS has no
   --  /bin/true at all -- true lives in /usr/bin there -- so the path is probed
   --  rather than assumed.
   --  @return an absolute path to an executable that exits 0 and does nothing
   function No_Op_Executable return String;

   --  Does this path exist? False, rather than an exception, for a name the host
   --  cannot even represent.
   --
   --  Ada.Directories.Exists raises Name_Error on Windows for a name containing
   --  ':' or '\\', which are ordinary characters on POSIX. Tests that check an
   --  invalid name was REFUSED then ask whether the file exists -- and a path the
   --  operating system cannot name certainly does not.
   --  @param Path the path to test
   --  @return True when Path exists; False for a name the host cannot represent
   function Path_Exists (Path : String) return Boolean;

   --  The root of the filesystem the scratch root lives on: "/" on POSIX, and the
   --  drive -- "C:\" -- on Windows, where "/" is not a root at all.
   --  @return the filesystem root containing the scratch root
   function Filesystem_Root return String;

   --  A real executable that fails, for tests that check a non-zero exit is not
   --  surfaced. Like true, false lives in /usr/bin on macOS, not /bin.
   --  @return an absolute path to an executable that exits non-zero
   function Failing_Executable return String;

   --  A real executable that records having run, by creating the file named as its
   --  first argument. Lets a test prove an action did not merely *report* that it
   --  was never launched, but genuinely never ran.
   --  @return an absolute path to an executable that creates its first argument
   function Marker_Executable return String;

   --  True when the filesystem under Root treats "A.txt" and "a.txt" as the same
   --  file, as macOS does by default. Fixtures that rely on both existing at once
   --  cannot be built there, and must say so rather than quietly measure the
   --  wrong thing.
   --  @return True when the filesystem under Root is case-insensitive
   function Case_Insensitive_Filesystem return Boolean;

   --  Translate a simulated click against a snapshot into an input action.
   --
   --  @param Snapshot View snapshot the click is tested against.
   --  @param X Click X coordinate in pixels.
   --  @param Y Click Y coordinate in pixels.
   --  @param Width Window width in pixels.
   --  @param Height Window height in pixels.
   --  @param Activate True for a double-click/activation.
   --  @param Modifiers Active keyboard modifiers.
   --  @param Line_Height Text line height in pixels.
   --  @return The resulting input action.
   function Click_Action
     (Snapshot    : Files.Rendering.View_Snapshot;
      X           : Natural;
      Y           : Natural;
      Width       : Natural;
      Height      : Natural;
      Activate    : Boolean := False;
      Modifiers   : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Line_Height : Positive := 20)
      return Files.Events.Input_Action;

   --  Create a symbolic link.
   --
   --  @param Target Path the link points to.
   --  @param Linkpath Path of the link to create.
   --  @return True when the link was created.
   function Create_Symlink (Target : String; Linkpath : String) return Boolean;

   --  The kinds of link a fixture makes.
   type Link_Kind is (Symbolic_Link, Hard_Link);

   --  Report that Test could not make the link its fixture needs, instead of
   --  passing without checking anything. On Linux both kinds of link always
   --  work in the test root, so there it is a failure. Elsewhere it is a
   --  recorded skip -- a symbolic link is a privilege on Windows (Developer
   --  Mode or the create-symbolic-link right), and a file another handle holds
   --  may refuse a second name there -- which CI's per-host skip ceiling still
   --  turns red if it starts happening.
   --
   --  @param Test The test routine.
   --  @param Kind The link that could not be made.
   procedure Link_Not_Made (Test : String; Kind : Link_Kind := Symbolic_Link);

   --  Delete and recreate the temporary test root directory.
   procedure Reset_Root;

   --  Make Path one its owner cannot delete, where locking its folder alone
   --  does not stop that. On POSIX a mode-555 folder refuses every unlink in
   --  it, so this does nothing there. On Windows deleting needs DELETE on the
   --  entry itself or FILE_DELETE_CHILD on its folder, and an entry made
   --  before its folder was locked keeps DELETE through the ACE it inherited;
   --  there Path's own DACL is made read-only (444, 555 for a folder), which
   --  binds an elevated process too. Allow_Deletion undoes it.
   --
   --  @param Path An existing file or folder.
   procedure Forbid_Deletion (Path : String);

   --  Path's access as the host reports it, for a failure message: icacls'
   --  listing on Windows, "" elsewhere.
   --
   --  @param Path An existing file or folder.
   --  @param Tree Whether to list everything under Path as well.
   --  @return The listing.
   function Access_Report (Path : String; Tree : Boolean := False) return String;

   --  Give Path's owner write and delete access back after Forbid_Deletion
   --  (644, 755 for a folder). Nothing on POSIX, nor when nothing is there.
   --
   --  @param Path A file or folder Forbid_Deletion was given.
   procedure Allow_Deletion (Path : String);

   --  Create or replace a file with byte-for-byte Content through
   --  Hostkit.Fs.Create_Stream, which reaches past Windows' 260-character
   --  path limit where GNAT's own file calls stop.
   --
   --  @param Path File to create.
   --  @param Content Raw bytes represented as String characters.
   procedure Write_Long_Path_File (Path : String; Content : String);

   --  Does the file at Path hold exactly these bytes? Read through
   --  Hostkit.Fs.Open_Stream, past Windows' path limit.
   --
   --  @param Path File to read.
   --  @param Bytes Expected content, byte for byte.
   --  @return True when the file is there and holds exactly Bytes.
   function Long_Path_File_Is (Path : String; Bytes : String) return Boolean;

   --  Create or replace a text file with Content.
   --
   --  @param Path File to create.
   --  @param Content Text to write.
   procedure Write_File (Path : String; Content : String := "x");

   --  Create or replace a file with byte-for-byte Content.
   --
   --  @param Path File to create.
   --  @param Content Raw bytes represented as String characters.
   procedure Write_Binary_File (Path : String; Content : String);

   --  Does the file hold this exact byte sequence anywhere in it?
   --
   --  Byte-exact, so it works on binary artifacts that a line- and
   --  encoding-aware text search cannot read: the thumbnail cache is binary P6,
   --  where a pixel is three raw bytes rather than three ASCII numbers.
   --
   --  @param Path File to search.
   --  @param Bytes Sequence to look for, one Character per byte.
   --  @return True when the sequence appears.
   function File_Has_Bytes (Path : String; Bytes : String) return Boolean;

   --  Does the file hold exactly these bytes, and nothing else? Where a test
   --  knows a file's whole content, this is the check: File_Has_Bytes also
   --  passes for an append instead of a truncate, or a torn replace that left
   --  old and new together.
   --
   --  @param Path File to read.
   --  @param Bytes Its whole expected content, one Character per byte.
   --  @return True when the file exists and holds exactly Bytes.
   function File_Is (Path : String; Bytes : String) return Boolean;

   --  Create a file of Filler_Count copies of one byte followed by Trailer,
   --  written in chunks so the caller need not build a multi-megabyte String.
   --  For exercising the metadata readers' byte-scan caps, which only engage on
   --  files larger than several megabytes.
   --
   --  @param Path File to create.
   --  @param Filler Byte repeated Filler_Count times.
   --  @param Filler_Count How many copies of Filler to write first.
   --  @param Trailer Bytes written after the filler run.
   procedure Write_Filler_File
     (Path         : String;
      Filler       : Character;
      Filler_Count : Natural;
      Trailer      : String := "");

   --  Join a parent directory and a name into a path.
   --
   --  @param Parent Parent directory path.
   --  @param Name Entry name to append.
   --  @return The joined path.
   function Join (Parent : String; Name : String) return String;

   --  Build a sample set of directory items for tests.
   --
   --  @return A vector of sample directory items.
   function Sample_Items return Files.Items.Item_Vectors.Vector;

   --  Build a sample window model populated with sample items.
   --
   --  @return A sample window model.
   function Sample_Model return Files.Model.Window_Model;

   --  Select the item with the given name in the model.
   --
   --  @param Model Model whose selection is updated.
   --  @param Name Name of the item to select.
   procedure Select_Name (Model : in out Files.Model.Window_Model; Name : String);

   --  An extra info written compactly for an expectation ("text.lines_encoding|1|ascii"):
   --  the kind, then its fields. Only ever written, never read back.
   --
   --  @param Extra The extra info.
   --  @return Its description, "" for none.
   function Describe (Extra : Files.Extra_Info.Info) return String;

   --  The N-th file of a numbered paste fixture (Arm_Numbered_Paste).
   --
   --  @param Directory Directory the fixture's files are in.
   --  @param N Number of the file.
   --  @return The path of "f<N>.txt" in Directory.
   function Numbered_File (Directory : String; N : Positive) return String;

   --  A paste execution over Count numbered files, armed and not yet
   --  advanced: the root reset, files f1.txt .. in Src_Dir (holding S1 ..),
   --  Model opened on the empty Dest_Dir, and a copy of each into it.
   --
   --  @param Model Window model to open on Dest_Dir.
   --  @param Settings Settings the destination is listed with.
   --  @param Src_Dir Directory the sources are written to.
   --  @param Dest_Dir Directory they are copied into.
   --  @param Count Number of files.
   procedure Arm_Numbered_Paste
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Src_Dir  : String;
      Dest_Dir : String;
      Count    : Positive);

   --  An action's items from its path lists, for a fixture recorded through
   --  Files.Undo_Recording: item Index has From (Index) and the Index-th of
   --  each other list, or "" past its end.
   --
   --  @param From Current locations.
   --  @param To Old locations or values.
   --  @param Forward Redo sources or new values.
   --  @param Identities Identities as published.
   --  @param Tree_Revisions Tree revisions as published.
   --  @param Provenance How the record knows each item: Captured reads its
   --    identity afresh, ignoring Identities and Tree_Revisions.
   --  @return The items, in From's order.
   function Undo_Items
     (From           : Files.Types.String_Vectors.Vector;
      To             : Files.Types.String_Vectors.Vector := Files.Types.String_Vectors.Empty_Vector;
      Forward        : Files.Types.String_Vectors.Vector := Files.Types.String_Vectors.Empty_Vector;
      Identities     : Files.Types.String_Vectors.Vector := Files.Types.String_Vectors.Empty_Vector;
      Tree_Revisions : Files.Types.String_Vectors.Vector := Files.Types.String_Vectors.Empty_Vector;
      Provenance     : Files.Model.Item_Provenance := Files.Model.Captured)
      return Files.Model.Recorded_Item_Vectors.Vector;

   --  Originals a replace preserved at Trash, their identities and targets
   --  to be captured.
   --
   --  @param Trash Where each is preserved.
   --  @return The originals, in order.
   function Replaced_Originals
     (Trash : Files.Types.String_Vectors.Vector) return Files.Model.Recorded_Original_Vectors.Vector;

end Files_Suite.Support;
