with Files.Events;
with Files.File_System;
with Files.Model;
with Files.Rendering;
with Guikit.Input;
with Files.Types;

package Files_Suite.Support is

   --  The scratch directory every fixture builds under.
   --
   --  This is deliberately not a hardcoded "/tmp/...": on macOS /tmp is a
   --  symlink into /private, so the application's canonicalised paths never
   --  string-compare equal to a path spelled through it, and Windows has no /tmp
   --  at all. Test_Root resolves the platform's real temporary directory,
   --  following links, so a path built here matches the one the model reports.
   --  A function, not a constant: a spec-level constant cannot call into the
   --  body before that body is elaborated.
   function Root return String;

   --  A real executable that succeeds and does nothing, for tests that need an
   --  action to actually run. It is NOT /bin/true everywhere: macOS has no
   --  /bin/true at all -- true lives in /usr/bin there -- so the path is probed
   --  rather than assumed.
   function No_Op_Executable return String;

   --  Does this path exist? False, rather than an exception, for a name the host
   --  cannot even represent.
   --
   --  Ada.Directories.Exists raises Name_Error on Windows for a name containing
   --  ':' or '\\', which are ordinary characters on POSIX. Tests that check an
   --  invalid name was REFUSED then ask whether the file exists -- and a path the
   --  operating system cannot name certainly does not.
   function Path_Exists (Path : String) return Boolean;

   --  A real executable that fails, for tests that check a non-zero exit is not
   --  surfaced. Like true, false lives in /usr/bin on macOS, not /bin.
   function Failing_Executable return String;

   --  True when the filesystem under Root treats "A.txt" and "a.txt" as the same
   --  file, as macOS does by default. Fixtures that rely on both existing at once
   --  cannot be built there, and must say so rather than quietly measure the
   --  wrong thing.
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

end Files_Suite.Support;
