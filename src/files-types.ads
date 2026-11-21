with Ada.Calendar;
with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

with Guikit.Shared_Bytes;
with Hostkit.Metadata;

--  Shared value types used across the files model, commands, and rendering.
package Files.Types is
   --  The time a record holds when it has none: a date no file carries, so
   --  it is never mistaken for one (the matching Available flag says so too).
   Unknown_Time : constant Ada.Calendar.Time := Ada.Calendar.Time_Of (1901, 1, 1);

   --  How many bytes a streaming read or copy moves per call: the size of
   --  the one buffer every such loop reuses.
   IO_Chunk_Bytes : constant := 64 * 1024;

   subtype UString is Ada.Strings.Unbounded.Unbounded_String;

   package String_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => UString,
      "="          => Ada.Strings.Unbounded."=");

   --  What became of an item whose labels, favorites and recent entries
   --  should follow it: it now lives elsewhere, or it is gone for good.
   type Path_Move_Kind is (Moved, Removed);

   --  One rename, move or removal. To is the new full path of a Moved item
   --  and empty for a Removed one.
   type Path_Move is record
      From : UString;
      To   : UString;
      Kind : Path_Move_Kind := Moved;
   end record;

   package Path_Move_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Path_Move);

   --  Byte buffer type shared with the renderer-agnostic draw model, which
   --  renames the same Guikit.Shared_Bytes instance: application code keeps
   --  using Files.Types.Byte_Vectors without depending on the draw model.
   package Byte_Vectors renames Guikit.Shared_Bytes.Byte_Vectors;

   --  A numeric user or group id. Re-exported from Hostkit.Metadata, which
   --  reads and sets them: uid_t and gid_t are unsigned 32-bit, and ids from
   --  2**31 up are real ones (an idmapped mount, NFS's nobody at 4294967294),
   --  so a Natural cannot hold them. `use type Files.Types.Account_Id` makes
   --  its operators visible.
   subtype Account_Id is Hostkit.Metadata.Account_Id;
   subtype Parsed_Account_Id is Hostkit.Metadata.Parsed_Account_Id;

   --  The id in decimal, without a leading blank: "4294967294".
   --
   --  @param Id Account id to print.
   --  @return Its decimal digits.
   function Account_Image (Id : Account_Id) return String
     renames Hostkit.Metadata.Account_Image;

   --  Read a decimal id: ASCII digits only, at most 4294967295. Never raises.
   --
   --  @param Text Candidate decimal id.
   --  @return Whether Text is a valid id, and the id when it is.
   function Parse_Account_Id (Text : String) return Parsed_Account_Id
     renames Hostkit.Metadata.Parse_Account_Id;

   --  The field items are sorted by: the one enumeration the model, the
   --  settings file and the sort commands share. This declaration order is
   --  the sort menu's row order. The settings file stores each field as its
   --  own token (Files.Settings owns that mapping), never as a position.
   type Sort_Field is
     (Sort_Name,
      Sort_Size,
      Sort_Type,
      Sort_Created,
      Sort_Changed);

   --  The listing policy a directory load applies: whether hidden entries are
   --  listed, and the order the listed items are sorted into. A load reads only
   --  these from the settings for filtering and ordering, so a caller with its
   --  own policy (emptying the Trash lists hidden payloads too) states it here
   --  instead of editing a copy of the whole settings.
   type Listing_Options is record
      Show_Hidden    : Boolean := False;
      Sort_Field     : Files.Types.Sort_Field := Sort_Name;
      Sort_Ascending : Boolean := True;
   end record;

   type Item_Kind is
     (Directory_Item,
      Regular_File_Item,
      Symlink_Item,
      Executable_Item,
      Unknown_Item,
      Other_Item);
end Files.Types;
