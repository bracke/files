with Hostkit.Fs;

--  How long a leaf name a filesystem stores, and how to cut one down to fit.
--
--  Pure rules, with no filesystem access: the caller says how the
--  destination measures a name (Hostkit.Fs.Leaf_Name_Limit_At for the
--  destination directory), so every host checks every measure alike and the
--  tests run them on Linux.
package Files.Leaf_Names is

   use type Hostkit.Fs.Name_Length_Unit;

   --  The measure where nothing better is known: 255 bytes, POSIX's own.
   Default_Limit : constant Hostkit.Fs.Leaf_Name_Limit := (Unit => Hostkit.Fs.Bytes, Most => 255);

   --  The length of Name in the given unit.
   --
   --  @param Name A leaf name, UTF-8 encoded.
   --  @param Unit How the destination counts: bytes, or UTF-16 units (NTFS,
   --    FAT, exFAT, SMB, APFS, HFS+).
   --  @return UTF-16 units -- bytes when Name is not valid UTF-8, which never
   --    undercounts -- or bytes.
   function Length_Under
     (Name : String;
      Unit : Hostkit.Fs.Name_Length_Unit)
      return Natural;

   --  Whether Name is longer than a filesystem with the given limit stores.
   --
   --  @param Name A leaf name, UTF-8 encoded.
   --  @param Limit The destination's limit (Hostkit.Fs.Leaf_Name_Limit_At).
   --  @return True when Length_Under (Name, Limit.Unit) exceeds Limit.Most.
   function Too_Long_Under
     (Name  : String;
      Limit : Hostkit.Fs.Leaf_Name_Limit)
      return Boolean is
     (Length_Under (Name, Limit.Unit) > Limit.Most);

   --  How many names a search for a free one tries (First_Free) before it
   --  gives up: a folder holding this many numbered copies of one name is
   --  pathological, and every try may ask a disk.
   Max_Attempts : constant := 9_999;

   --  Where a marker goes: before the extension ("notes 2.txt"), or after
   --  the whole name ("notes.txt.2", as a trash names its payloads).
   type Marker_Place is (Before_Extension, After_Name);

   --  " (Word)" for the first attempt (0 or 1), " (Word N)" from the
   --  second: the marker a duplicate (copy), a link (link) and a case-only
   --  rename's scratch name (renaming) are told apart by. Word is a fixed,
   --  unlocalized file-name word, the same on every locale.
   --
   --  @param Word The word in the parentheses.
   --  @param Attempt The attempt.
   --  @return The marker, starting with its blank.
   function Counted_Marker (Word : String; Attempt : Natural) return String;

   --  "" for attempt 0, " (N)" from 1: an archive's or an extracted
   --  folder's name, the bare name first.
   --
   --  @param Attempt The attempt.
   --  @return The marker.
   function Numbered_Marker (Attempt : Natural) return String;

   --  "" for attempts 0 and 1, " N" from 2: a paste's, a drop's, an
   --  untitled file's and a released recovery's name, the bare name first.
   --
   --  @param Attempt The attempt.
   --  @return The marker.
   function Spaced_Number (Attempt : Natural) return String;

   --  "" for attempts 0 and 1, ".N" from 2: a freedesktop trash payload's
   --  name, placed After_Name.
   --
   --  @param Attempt The attempt.
   --  @return The marker.
   function Dotted_Number (Attempt : Natural) return String;

   --  Stem, Marker and Extension made one leaf name that a filesystem with
   --  the given limit stores: the stem loses whole characters from its end
   --  (Cut); the marker and an extension of up to 32 bytes are kept whole,
   --  and a longer one goes by Fit's rule instead. A name that fits comes
   --  back as it is, Marker in its place.
   --
   --  @param Stem The name before its extension (all of a folder's name).
   --  @param Extension Its extension without the dot, or "".
   --  @param Marker What tells this name apart (Counted_Marker and the rest).
   --  @param Limit How long a name the destination stores.
   --  @param Place Where Marker goes.
   --  @return The leaf name.
   function Candidate
     (Stem      : String;
      Extension : String;
      Marker    : String;
      Limit     : Hostkit.Fs.Leaf_Name_Limit;
      Place     : Marker_Place := Before_Extension)
      return String;

   --  The first of the Candidate names for attempts First .. Max_Attempts
   --  that Taken says is free: the one search for a free name every
   --  operation makes. Taken decides how "in use" is told -- on a disk it
   --  is Files.IO.Fs_Primitives.Is_Taken, which raises on a lookup the host
   --  refuses, so a name that may be in use is never handed out.
   --
   --  @param Stem The name before its extension (all of a folder's name).
   --  @param Extension Its extension without the dot, or "".
   --  @param Marker The marker for an attempt.
   --  @param Taken Whether a leaf name is in use.
   --  @param Limit How long a name the destination stores.
   --  @param First The first attempt (0 or 1: the bare name, where the
   --    marker gives it).
   --  @param Place Where the marker goes.
   --  @return A free leaf name, or "" when every attempt is taken.
   function First_Free
     (Stem      : String;
      Extension : String;
      Marker    : not null access function (Attempt : Natural) return String;
      Taken     : not null access function (Leaf : String) return Boolean;
      Limit     : Hostkit.Fs.Leaf_Name_Limit;
      First     : Natural := 1;
      Place     : Marker_Place := Before_Extension)
      return String;

private

   --  Name with Insert placed before its extension, its stem cut down as
   --  Cut cuts so the whole measures at most Room. The extension -- from the
   --  last dot, unless the name starts with that dot or it is longer than 32
   --  bytes -- is kept whole; a name that fits as it is comes back unchanged
   --  but for Insert.
   --
   --  @param Name A leaf name, UTF-8 encoded.
   --  @param Room The most the result may measure (Length_Under).
   --  @param Unit How the result is measured.
   --  @param Insert Text placed between the stem and the extension.
   --  @return The fitted name.
   function Fit
     (Name   : String;
      Room   : Natural;
      Unit   : Hostkit.Fs.Name_Length_Unit := Hostkit.Fs.Bytes;
      Insert : String := "")
      return String;

   --  Head cut down at a whole UTF-8 character, as little as needed, with
   --  Tail kept whole after it, so the result measures at most Room.
   --
   --  @param Head The part that may be shortened (a stem).
   --  @param Tail The part kept whole (a counter and an extension).
   --  @param Room The most the result may measure (Length_Under).
   --  @param Unit How the result is measured.
   --  @return Head's longest prefix that fits, then Tail; just Tail when no
   --    prefix fits, which then may still not.
   function Cut
     (Head : String;
      Tail : String;
      Room : Natural;
      Unit : Hostkit.Fs.Name_Length_Unit := Hostkit.Fs.Bytes)
      return String;

end Files.Leaf_Names;
