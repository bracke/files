with Ada.Finalization;
with Ada.Iterator_Interfaces;
with Ada.Real_Time;
with Files.Commands;
with Files.Controller;
with Files.Events;
with Files.File_System;
with Files.Model;
with Files.Operations;
with Files.Rendering;
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

   --  Whether Test called Skip in this run.
   --
   --  @param Test A test routine's name, as passed to Skip.
   --  @return True when it skipped.
   function Skipped_Test (Test : String) return Boolean;

   --  The tests that skipped, each once, in the order they first did.
   --
   --  @return Their names.
   function Skipped_Tests return Files.Types.String_Vectors.Vector;

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

   --  Run a command the way the application does, through the one dispatch
   --  path (Files.Controller.Execute_Command) with default settings, for a
   --  test that checks the command's effect on the model and not its result.
   --
   --  @param Id Command to run.
   --  @param Model Window model the command acts on.
   procedure Run_Command
     (Id    : Files.Commands.Command_Id;
      Model : in out Files.Model.Window_Model);

   --  Assert_Equal for the enumerations the suite compares most.
   procedure Assert_Equal is new Files_Suite.Generic_Assert_Equal (Files.Operations.Operation_Status);
   procedure Assert_Equal is new Files_Suite.Generic_Assert_Equal (Files.Commands.Command_Id);
   procedure Assert_Equal is new Files_Suite.Generic_Assert_Equal (Files.Controller.Controller_Status);
   procedure Assert_Equal is new Files_Suite.Generic_Assert_Equal (Files.Types.Focus_Target);
   procedure Assert_Equal is new Files_Suite.Generic_Assert_Equal (Guikit.Input.Key_Code);
   procedure Assert_Equal is new Files_Suite.Generic_Assert_Equal (Files.Commands.Command_Placement);
   procedure Assert_Equal is new Files_Suite.Generic_Assert_Equal (Files.Events.Input_Action_Kind);
   procedure Assert_Equal is new Files_Suite.Generic_Assert_Equal (Files.Types.Color_Label);
   procedure Assert_Equal is new Files_Suite.Generic_Assert_Equal (Files.Types.Account_Id);
   procedure Assert_Equal is new Files_Suite.Generic_Assert_Equal (Files.Types.View_Mode);
   procedure Assert_Equal is new Files_Suite.Generic_Assert_Equal (Files.Types.Detail_Column);
   procedure Assert_Equal is new Files_Suite.Generic_Assert_Equal (Files.Types.Sort_Field);
   procedure Assert_Equal is new Files_Suite.Generic_Assert_Equal (Files.Types.Group_Mode);

   --  A point on the monotonic clock (Ada.Real_Time): timing assertions
   --  measure with it rather than with Ada.Calendar's wall clock, which an
   --  NTP step or a daylight-saving change can move by any amount.
   subtype Instant is Ada.Real_Time.Time;

   --  A span of monotonic time.
   subtype Span is Ada.Real_Time.Time_Span;

   --  @return The monotonic clock now.
   function Now return Instant;

   --  @param Since An earlier reading of Now.
   --  @return How long ago Since was.
   function Elapsed (Since : Instant) return Span;

   --  @param Taken A span.
   --  @return Taken in seconds.
   function Seconds (Taken : Span) return Duration;

   --  The factor every timing bound is multiplied by: the decimal in
   --  FILES_TEST_TIME_SCALE (CI sets 2 on its slow shared macOS and Windows
   --  runners), or 1.0 when it is unset, unreadable or below 1.0, so a slow
   --  host can be given room without editing the tests, and no host can be
   --  made stricter than the defaults below.
   --
   --  @return The scale, at least 1.0.
   function Time_Scale return Duration;

   --  @param Bound A default bound, in seconds.
   --  @return Bound multiplied by Time_Scale.
   function Scaled (Bound : Duration) return Span;

   --  How long a call may take and still count as not waiting for a stalled
   --  helper (which never finishes): long enough for a loaded CI runner to
   --  spawn a process, far short of anything that would wait.
   Prompt_Seconds : constant Duration := 1.0;

   --  How long a call that starts a helper process may take: a spawn alone
   --  can exceed a quarter second on a busy Windows runner, and a call that
   --  inspected the stalled target itself would block far longer.
   Launch_Seconds : constant Duration := 2.0;

   --  How long cancelling a stalled helper may take to report it detached:
   --  the helper's bounded grace period plus the reaping after it.
   Detach_Seconds : constant Duration := 3.5;

   --  @return Prompt_Seconds, scaled.
   function Prompt_Limit return Span is (Scaled (Prompt_Seconds));

   --  @return Launch_Seconds, scaled.
   function Launch_Limit return Span is (Scaled (Launch_Seconds));

   --  @return Detach_Seconds, scaled.
   function Detach_Limit return Span is (Scaled (Detach_Seconds));

   --  Assert that Taken is under Limit; the failure message says both, in
   --  seconds, so a slow-runner failure tells by how much it missed.
   --
   --  @param Taken Measured span.
   --  @param Limit Bound it must stay under.
   --  @param Message What the check is about.
   procedure Assert_Within (Taken : Span; Limit : Span; Message : String);

   --  Assert_Within (Elapsed (Since), Limit, Message). Call it straight after
   --  the measured call, before any other check, so only that call is timed.
   --
   --  @param Since Reading of Now taken just before the measured call.
   --  @param Limit Bound it must stay under.
   --  @param Message What the check is about.
   procedure Assert_Within (Since : Instant; Limit : Span; Message : String);

   --  How long a test waits for something it expects to happen (a helper
   --  starting, a job finishing) before giving up. Generous, because a wait
   --  only runs this long when the test is already failing.
   Poll_Limit : constant Duration := 30.0;

   type Poll_Cursor is new Natural;

   --  @param Position A polling cursor.
   --  @return True while the wait has time left.
   function Has_Poll (Position : Poll_Cursor) return Boolean is (Position /= 0);

   package Poll_Iterators is new Ada.Iterator_Interfaces (Poll_Cursor, Has_Poll);

   --  Iterate until a deadline: "for Attempt in Polling loop ... exit when
   --  Done; end loop;" runs the body, sleeps Interval, and runs it again
   --  until the body exits or Limit has passed. The caller asserts the
   --  condition afterwards, as with any bounded wait.
   --
   --  @param Limit Wall-clock bound on the whole wait.
   --  @param Interval Sleep between attempts.
   --  @return An iterator over the attempts.
   function Polling
     (Limit    : Duration := Poll_Limit;
      Interval : Duration := 0.001)
      return Poll_Iterators.Forward_Iterator'Class;

   --  Restores the environment variables it saved when it leaves scope,
   --  whether the test passed or an assertion raised, so a failing test
   --  cannot leave HOME or TMPDIR pointing into its fixtures.
   type Environment_Guard is new Ada.Finalization.Limited_Controlled with private;

   --  Remember Name's current value (or that it is unset) for restoring.
   --
   --  @param Guard Guard that restores it.
   --  @param Name Environment variable name.
   procedure Save (Guard : in out Environment_Guard; Name : String);

   --  Put every saved variable back as it was.
   --
   --  @param Guard Guard leaving scope.
   overriding procedure Finalize (Guard : in out Environment_Guard);

   --  Clears every global shortcut override (Files.Commands) when it leaves
   --  scope, whether the test passed or an assertion raised, so a failing
   --  shortcut test cannot leave its bindings in force for the rest of the
   --  suite. Declaring one does not clear anything; a test that needs a clean
   --  start still calls Files.Commands.Reset_Shortcut_Overrides first.
   type Shortcut_Guard is new Ada.Finalization.Limited_Controlled with null record;

   --  Clear every shortcut override.
   --
   --  @param Guard Guard leaving scope.
   overriding procedure Finalize (Guard : in out Shortcut_Guard);

   --  Puts the working directory back to what it was when the guard was
   --  declared, when it leaves scope -- on an assertion failure too -- so a
   --  test that changes directory cannot leave the rest of the suite running
   --  somewhere else. A restore that fails is reported on standard error
   --  (a finalizer must not raise); the test that owned the guard is not
   --  failed by it.
   type Directory_Guard is new Ada.Finalization.Limited_Controlled with private;

   --  Remember the current working directory.
   --
   --  @param Guard Guard being declared.
   overriding procedure Initialize (Guard : in out Directory_Guard);

   --  Change back to the remembered working directory.
   --
   --  @param Guard Guard leaving scope.
   overriding procedure Finalize (Guard : in out Directory_Guard);

   --  @param Guard A guard.
   --  @return The working directory Guard restores.
   function Saved_Directory (Guard : Directory_Guard) return String;

   --  Drive every queued background folder-size walk of Model to completion,
   --  publishing each result as the frame loop's Poll_All_Folder_Sizes would,
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

   --  Convert a byte value to its Character.
   --
   --  @param Value Byte value (0 .. 255).
   --  @return The corresponding Character.
   function Byte (Value : Natural) return Character;

   --  Build a minimal PNG header for the given dimensions.
   --
   --  @param Width Image width in pixels.
   --  @param Height Image height in pixels.
   --  @return The encoded PNG header bytes.
   function Minimal_Png_Header (Width : Natural; Height : Natural) return String;

   --  Wrap a payload in a stored (uncompressed) zlib stream.
   --
   --  @param Payload Raw bytes to store.
   --  @return The encoded zlib stream.
   function Stored_Zlib_Stream (Payload : String) return String;

   --  Build a PNG chunk with the given type and data.
   --
   --  @param Kind Four-character chunk type.
   --  @param Data Chunk payload bytes.
   --  @return The encoded chunk (length, type, data, CRC).
   function Chunk (Kind : String; Data : String) return String;

   --  Build a minimal RGB PNG from a raw pixel payload.
   --
   --  @param Width Image width in pixels.
   --  @param Height Image height in pixels.
   --  @param Payload Raw pixel bytes.
   --  @return The encoded PNG file bytes.
   function Minimal_Png_RGB
     (Width   : Natural;
      Height  : Natural;
      Payload : String)
      return String;

   --  Build a minimal JPEG filled with a solid value.
   --
   --  @param Width Image width in pixels.
   --  @param Height Image height in pixels.
   --  @return The encoded JPEG file bytes.
   function Minimal_Jpeg_With_Fill (Width : Natural; Height : Natural) return String;

   --  Join a parent directory and a name into a path.
   --
   --  @param Parent Parent directory path.
   --  @param Name Entry name to append.
   --  @return The joined path.
   function Join (Parent : String; Name : String) return String;

   --  Build a sample set of directory items for tests.
   --
   --  @return A vector of sample directory items.
   function Sample_Items return Files.File_System.Item_Vectors.Vector;

   --  Build a sample window model populated with sample items.
   --
   --  @return A sample window model.
   function Sample_Model return Files.Model.Window_Model;

   --  Select the item with the given name in the model.
   --
   --  @param Model Model whose selection is updated.
   --  @param Name Name of the item to select.
   procedure Select_Name (Model : in out Files.Model.Window_Model; Name : String);

private

   type Poll_Iterator is new Poll_Iterators.Forward_Iterator with record
      Deadline : Ada.Real_Time.Time;
      Interval : Duration;
   end record;

   overriding function First (Object : Poll_Iterator) return Poll_Cursor is (1);

   overriding function Next (Object : Poll_Iterator; Position : Poll_Cursor) return Poll_Cursor;

   type Saved_Variable is record
      Name  : Files.Types.UString;
      Value : Files.Types.UString;
      Was   : Boolean := False;
   end record;

   type Saved_Variables is array (1 .. 8) of Saved_Variable;

   type Environment_Guard is new Ada.Finalization.Limited_Controlled with record
      Count : Natural := 0;
      Saved : Saved_Variables;
   end record;

   type Directory_Guard is new Ada.Finalization.Limited_Controlled with record
      Saved : Files.Types.UString;
   end record;

end Files_Suite.Support;
