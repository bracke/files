with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Streams;
with Ada.Strings.Hash;
with Ada.Strings.Unbounded;

with GNAT.OS_Lib;

with Files.Fs;
with Files.Resources;
with Guikit.Draw;

package body Files.Icon_Assets is

   use Ada.Strings.Unbounded;

   package Text_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => String,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

   Cache : Text_Maps.Map;
   Max_Icon_Asset_Bytes : constant := 64 * 1024;

   function Valid_Icon_Id (Value : String) return Boolean is
   begin
      if Value'Length not in 1 .. 64 then
         return False;
      end if;

      for Item of Value loop
         if Item not in 'a' .. 'z' | '0' .. '9' | '-' | '_' then
            return False;
         end if;
      end loop;
      return True;
   end Valid_Icon_Id;

   function Valid_Theme_Name (Value : String) return Boolean is
     (Value in "" | "files-basic" | "files-high-contrast");

   function Icons_Root return String is
     (Files.Resources.Share_Path ("files/icons"));

   --  Read one small icon definition byte-for-byte. Returns "" on any error.
   function Read_File (Path : String) return String is
      use type Ada.Streams.Stream_Element_Offset;
      use type GNAT.OS_Lib.File_Descriptor;

      File   : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
      Buffer : Ada.Streams.Stream_Element_Array (1 .. 4096);
      Read   : Integer;
      Result : Unbounded_String;

      procedure Close_File is
      begin
         if File /= GNAT.OS_Lib.Invalid_FD then
            GNAT.OS_Lib.Close (File);
            File := GNAT.OS_Lib.Invalid_FD;
         end if;
      exception
         when others => null;
      end Close_File;
   begin
      File := Files.Fs.Open_Regular_Read_Following_Links (Path);
      if File = GNAT.OS_Lib.Invalid_FD then
         return "";
      end if;

      loop
         Read := GNAT.OS_Lib.Read
           (File, Buffer'Address, Integer (Buffer'Length));
         if Read < 0 then
            Close_File;
            return "";
         end if;
         exit when Read = 0;
         declare
            Chunk_Length : constant Natural := Natural (Read);
            Chunk : String (1 .. Chunk_Length);
         begin
            if Chunk_Length > Max_Icon_Asset_Bytes - Length (Result) then
               Close_File;
               return "";
            end if;
            for Index in Chunk'Range loop
               Chunk (Index) := Character'Val
                 (Buffer
                    (Ada.Streams.Stream_Element_Offset (Index)
                     + Buffer'First - 1));
            end loop;
            Append (Result, Chunk);
         end;
      end loop;
      Close_File;
      return To_String (Result);
   exception
      when others =>
         Close_File;
         return "";
   end Read_File;

   function Disk_Icon_Asset
     (Icon_Id    : String;
      Theme_Name : String)
      return String
   is
   begin
      if not Valid_Icon_Id (Icon_Id) or else not Valid_Theme_Name (Theme_Name) then
         return "";
      end if;

      declare
         Key  : constant String := Theme_Name & "|" & Icon_Id;
         Root : constant String := Icons_Root;
         Sub  : constant String :=
           (if Theme_Name = "files-high-contrast" then "/high-contrast" else "");
         Path : constant String := Root & Sub & "/" & Icon_Id & ".icon";
      begin
         if Root = "" then
            return "";
         end if;
         if Cache.Contains (Key) then
            return Cache.Element (Key);
         end if;

         declare
            Text : constant String := Read_File (Path);
         begin
            Cache.Insert (Key, Text);
            return Text;
         end;
      end;
   end Disk_Icon_Asset;

   procedure Register is
   begin
      Guikit.Draw.Set_Icon_Asset_Source (Disk_Icon_Asset'Access);
   end Register;

end Files.Icon_Assets;
