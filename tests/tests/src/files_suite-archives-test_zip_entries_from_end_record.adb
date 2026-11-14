separate (Files_Suite.Archives)
   procedure Test_Zip_Entries_From_End_Record (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      --  Little-endian fields.
      function U16 (Value : Natural) return String is
        (Byte (Value mod 256) & Byte (Value / 256 mod 256));
      function U32 (Value : Natural) return String is
        (U16 (Value mod 65_536) & U16 (Value / 65_536));
      function U64 (Value : Long_Long_Integer) return String is
        (Byte (Natural (Value mod 256)) & Byte (Natural (Value / 2 ** 8 mod 256))
         & Byte (Natural (Value / 2 ** 16 mod 256)) & Byte (Natural (Value / 2 ** 24 mod 256))
         & Byte (Natural (Value / 2 ** 32 mod 256)) & Byte (Natural (Value / 2 ** 40 mod 256))
         & Byte (Natural (Value / 2 ** 48 mod 256)) & Byte (Natural (Value / 2 ** 56 mod 256)));
      All_Ones_16 : constant String := Byte (255) & Byte (255);
      All_Ones_32 : constant String := All_Ones_16 & All_Ones_16;

      type Member is record
         Name : Unbounded_String;
         Data : Unbounded_String;
      end record;
      type Member_List is array (Positive range <>) of Member;

      function Stored (Name, Data : String) return Member is
        ((To_Unbounded_String (Name), To_Unbounded_String (Data)));

      --  Members stored (method 0): their local headers and data, and the
      --  central directory; the caller ends the archive.
      procedure Build
        (Members : Member_List;
         Locals  : out Unbounded_String;
         Central : out Unbounded_String) is
      begin
         Locals := Null_Unbounded_String;
         Central := Null_Unbounded_String;
         for Item of Members loop
            declare
               Name   : constant String := To_String (Item.Name);
               Data   : constant String := To_String (Item.Data);
               Offset : constant Natural := Length (Locals);
            begin
               Append
                 (Locals,
                  "PK" & Byte (3) & Byte (4) & U16 (10) & U16 (0) & U16 (0) & U16 (0) & U16 (0)
                  & U32 (0) & U32 (Data'Length) & U32 (Data'Length) & U16 (Name'Length) & U16 (0)
                  & Name & Data);
               Append
                 (Central,
                  "PK" & Byte (1) & Byte (2) & U16 (20) & U16 (10) & U16 (0) & U16 (0) & U16 (0) & U16 (0)
                  & U32 (0) & U32 (Data'Length) & U32 (Data'Length) & U16 (Name'Length) & U16 (0) & U16 (0)
                  & U16 (0) & U16 (0) & U32 (0) & U32 (Offset) & Name);
            end;
         end loop;
      end Build;

      --  A plain archive of Members.
      function Zip_Of (Members : Member_List) return String is
         Locals  : Unbounded_String;
         Central : Unbounded_String;
      begin
         Build (Members, Locals, Central);
         return To_String (Locals) & To_String (Central)
           & "PK" & Byte (5) & Byte (6) & U16 (0) & U16 (0) & U16 (Members'Length) & U16 (Members'Length)
           & U32 (Length (Central)) & U32 (Length (Locals)) & U16 (0);
      end Zip_Of;

      --  A ZIP64 archive of Members whose ZIP64 record states Total entries
      --  (the end record's fields all say "see ZIP64").
      function Zip64_Of
        (Members : Member_List;
         Total   : Long_Long_Integer)
         return String
      is
         Locals  : Unbounded_String;
         Central : Unbounded_String;
      begin
         Build (Members, Locals, Central);
         declare
            Record_At : constant Natural := Length (Locals) + Length (Central);
         begin
            return To_String (Locals) & To_String (Central)
              & "PK" & Byte (6) & Byte (6) & U64 (44) & U16 (45) & U16 (45) & U32 (0) & U32 (0)
              & U64 (Total) & U64 (Total) & U64 (Long_Long_Integer (Length (Central)))
              & U64 (Long_Long_Integer (Length (Locals)))
              & "PK" & Byte (6) & Byte (7) & U32 (0) & U64 (Long_Long_Integer (Record_At)) & U32 (1)
              & "PK" & Byte (5) & Byte (6) & All_Ones_16 & All_Ones_16 & All_Ones_16 & All_Ones_16
              & All_Ones_32 & All_Ones_32 & U16 (0);
         end;
      end Zip64_Of;

      function Entries_Of (Name : String; Content : String) return String is
         Path : constant String := Join (Root, Name);
      begin
         Write_Binary_File (Path, Content);
         return Files_Suite.Support.Describe
           (Files.File_System.Extra_Info_Of (Path, Files.Types.Regular_File_Item, "application/zip"));
      end Entries_Of;

      Three : constant Member_List :=
        [Stored ("a.txt", "one"), Stored ("b.txt", "two"), Stored ("c.txt", "three")];
      Inner : constant String := Zip_Of (Three);
   begin
      Reset_Root;
      Files_Suite.Support.Assert_Equal
        (Entries_Of ("plain.zip", Zip_Of (Three)), "archive.zip.entries|3", "a plain archive's entries are counted");
      --  The stored inner archive's central directory and end record are
      --  data of the outer one, as is a chance signature in a member.
      Files_Suite.Support.Assert_Equal
        (Entries_Of
           ("nested.zip",
            Zip_Of
              ([Stored ("inner.zip", Inner),
                Stored ("chance.bin", "PK" & Byte (1) & Byte (2) & "PK" & Byte (5) & Byte (6))])),
         "archive.zip.entries|2",
         "a stored inner archive's entries are not counted as the outer one's");
      Files_Suite.Support.Assert_Equal
        (Entries_Of ("zip64.zip", Zip64_Of (Three, 3)),
         "archive.zip.entries|3",
         "a ZIP64 archive's entries come from its ZIP64 record");
      --  A stub in front shifts the record from its stated offset.
      Files_Suite.Support.Assert_Equal
        (Entries_Of ("stub.zip", String'(1 .. 100 => 'x') & Zip64_Of (Three, 3)),
         "archive.zip.entries|3",
         "a ZIP64 record right before its locator is found behind a stub");
      Files_Suite.Support.Assert_Equal
        (Entries_Of ("huge.zip", Zip64_Of (Three, 2 ** 40)),
         "archive.zip.entries|" & Files.Types.Natural_Text (Natural'Last) & "+",
         "a ZIP64 count beyond Natural saturates and is marked capped");
      Files_Suite.Support.Assert_Equal
        (Entries_Of ("broken.zip", "PK" & Byte (3) & Byte (4) & "PK" & Byte (1) & Byte (2) & "no end record"),
         "archive.zip.entries|0",
         "an archive without an end record states no entries");
   end Test_Zip_Entries_From_End_Record;
