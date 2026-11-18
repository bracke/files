with Files.Leaf_Names;
with Hostkit.Fs;
separate (Files_Suite.Names)
   --  How long a name each filesystem stores, as a table: 255 bytes on a
   --  POSIX filesystem, 255 UTF-16 units on NTFS, FAT, exFAT, SMB, APFS and
   --  HFS+ -- where a name that is not UTF-8 counts its bytes, never fewer --
   --  and a long name cut down at whole characters, keeping what follows it.
   procedure Test_Leaf_Name_Length_Rules (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      --  U+00E9 (e acute): two bytes, one UTF-16 unit.
      E_Acute : constant String := Character'Val (16#C3#) & Character'Val (16#A9#);
      --  U+1F600: four bytes, a surrogate pair (two UTF-16 units).
      Emoji   : constant String :=
        Character'Val (16#F0#) & Character'Val (16#9F#) & Character'Val (16#98#) & Character'Val (16#80#);
      Invalid : constant Character := Character'Val (16#FF#);
      --  U+65E5 (a CJK character): three bytes, one UTF-16 unit.
      Cjk     : constant String := Character'Val (16#E6#) & Character'Val (16#97#) & Character'Val (16#A5#);

      Bytes_255 : constant Hostkit.Fs.Leaf_Name_Limit := (Unit => Hostkit.Fs.Bytes, Most => 255);
      Utf16_255 : constant Hostkit.Fs.Leaf_Name_Limit := (Unit => Hostkit.Fs.Utf16_Units, Most => 255);

      function Repeat (Item : String; Count : Natural) return String is (Ada.Strings.Fixed."*" (Count, Item));

      type Row is record
         Label     : Unbounded_String;
         Name      : Unbounded_String;
         Posix_Too : Boolean;
         Dos_Too   : Boolean;
      end record;

      function Make (Label, Name : String; Posix_Too, Dos_Too : Boolean) return Row is
        (To_Unbounded_String (Label), To_Unbounded_String (Name), Posix_Too, Dos_Too);

      Table : constant array (Positive range <>) of Row :=
        [Make ("255 ASCII bytes", [1 .. 255 => 'a'], False, False),
         Make ("256 ASCII bytes", [1 .. 256 => 'a'], True, True),
         Make ("128 two-byte characters", Repeat (E_Acute, 128), True, False),
         Make ("127 astral characters", Repeat (Emoji, 127), True, False),
         Make ("128 astral characters", Repeat (Emoji, 128), True, True),
         Make ("255 bytes that are not UTF-8", [1 .. 255 => Invalid], False, False),
         Make ("256 bytes that are not UTF-8", [1 .. 256 => Invalid], True, True),
         Make ("128 two-byte characters and a stray byte", Repeat (E_Acute, 128) & Invalid, True, True)];
   begin
      for Item of Table loop
         Assert
           (Files.Leaf_Names.Too_Long_Under (To_String (Item.Name), Bytes_255) = Item.Posix_Too,
            To_String (Item.Label) & ": POSIX rule");
         Assert
           (Files.Leaf_Names.Too_Long_Under (To_String (Item.Name), Utf16_255) = Item.Dos_Too,
            To_String (Item.Label) & ": UTF-16 rule");
      end loop;
      Assert (Files.Leaf_Names.Length_Under (Repeat (Emoji, 127), Hostkit.Fs.Utf16_Units) = 254,
              "an astral character is two UTF-16 units");
      Assert (Files.Leaf_Names.Length_Under (Repeat (Emoji, 127), Hostkit.Fs.Bytes) = 508,
              "and four bytes");

      --  A name of 100 CJK characters is 300 bytes: too long for ext4, but
      --  a volume counting UTF-16 units (APFS, HFS+, NTFS) holds it, so a
      --  rename back to it (an Undo) is not refused there.
      Assert (Files.Leaf_Names.Too_Long_Under (Repeat (Cjk, 100), Bytes_255),
              "100 CJK characters are too long for 255 bytes");
      Assert (not Files.Leaf_Names.Too_Long_Under (Repeat (Cjk, 100), Utf16_255),
              "100 CJK characters fit in 255 UTF-16 units");

      --  A volume that says it stores fewer (ecryptfs: 143 bytes) is held to
      --  that.
      Assert (Files.Leaf_Names.Too_Long_Under ([1 .. 144 => 'a'], (Unit => Hostkit.Fs.Bytes, Most => 143))
              and then not Files.Leaf_Names.Too_Long_Under ([1 .. 143 => 'a'], (Unit => Hostkit.Fs.Bytes, Most => 143)),
              "a smaller limit a volume states is the one that holds");

      --  Cutting: whole characters only, the tail kept, as little as needed.
      Files_Suite.Support.Assert_Equal
        (Files.Leaf_Names.Cut (Repeat (E_Acute, 128), " 2", 255),
         Repeat (E_Acute, 126) & " 2",
         "a cut drops whole two-byte characters to fit 255 bytes");
      Files_Suite.Support.Assert_Equal
        (Files.Leaf_Names.Cut (Repeat (E_Acute, 128), " 2", 255, Hostkit.Fs.Utf16_Units),
         Repeat (E_Acute, 128) & " 2",
         "130 UTF-16 units fit uncut");
      Files_Suite.Support.Assert_Equal
        (Files.Leaf_Names.Cut (Repeat (Emoji, 128), "", 255, Hostkit.Fs.Utf16_Units),
         Repeat (Emoji, 127),
         "a surrogate pair is never split");
      Files_Suite.Support.Assert_Equal
        (Files.Leaf_Names.Fit ([1 .. 300 => 'n'] & ".txt", 255),
         [1 .. 251 => 'n'] & ".txt",
         "a fitted name keeps its extension");
      Files_Suite.Support.Assert_Equal
        (Files.Leaf_Names.Fit ("notes.txt", 255, Insert => " (renaming)"),
         "notes (renaming).txt",
         "a short name only gains the insert, before its extension");
   end Test_Leaf_Name_Length_Rules;
