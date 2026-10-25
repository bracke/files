with Ada.Strings.Unbounded;

with GNAT.OS_Lib;

with Files.Fs_Primitives;

package body Files.Capped_Files is

   use type GNAT.OS_Lib.File_Descriptor;

   function Read_Capped
     (Path      : String;
      Max_Bytes : Natural;
      Links     : Link_Policy;
      Status    : out Read_Status)
      return String
   is
      File       : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
      Buffer     : String (1 .. 32 * 1024);
      Bytes_Read : Integer;
      Content    : Ada.Strings.Unbounded.Unbounded_String;
      Total      : Natural := 0;

      procedure Close_File is
      begin
         if File /= GNAT.OS_Lib.Invalid_FD then
            GNAT.OS_Lib.Close (File);
            File := GNAT.OS_Lib.Invalid_FD;
         end if;
      end Close_File;
   begin
      Status := Read_Failed;
      File :=
        (case Links is
            when Refuse_Links => Files.Fs_Primitives.Open_Regular_Read (Path),
            when Follow_Links => Files.Fs_Primitives.Open_Regular_Read_Following_Links (Path));
      if File = GNAT.OS_Lib.Invalid_FD then
         return "";
      end if;

      loop
         Bytes_Read := GNAT.OS_Lib.Read (File, Buffer'Address, Buffer'Length);
         if Bytes_Read < 0 then
            Close_File;
            return "";
         end if;
         exit when Bytes_Read = 0;
         if Bytes_Read > Max_Bytes - Total then
            Close_File;
            Status := Read_Too_Large;
            return "";
         end if;
         Ada.Strings.Unbounded.Append (Content, Buffer (1 .. Bytes_Read));
         Total := Total + Bytes_Read;
      end loop;
      Close_File;

      Status := Read_Complete;
      return Ada.Strings.Unbounded.To_String (Content);
   exception
      when others =>
         Close_File;
         Status := Read_Failed;
         return "";
   end Read_Capped;

end Files.Capped_Files;
