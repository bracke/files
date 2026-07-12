with Ada.Strings.Unbounded;
with Interfaces.C;
with System;
with Files.Platform.Windows.Trash;
with Files.Platform.Windows.Volumes;

package body Files.Platform.Windows is
   use Ada.Strings.Unbounded;
   use type Interfaces.C.int;
   use type Files.File_System.Native_API_Binding_Status;

   function GetUserDefaultLocaleName
     (Locale_Name : System.Address;
      Locale_Size : Interfaces.C.int)
      return Interfaces.C.int
     with Import, Convention => Stdcall, External_Name => "GetUserDefaultLocaleName";

   function API_Profile return Files.File_System.Native_Platform_API_Profile is
   begin
      return
        (Adapter               => Files.File_System.Native_Adapter_Windows,
         Trash_Binding_Status  => Files.Platform.Windows.Trash.Binding_Status,
         Volume_Binding_Status => Files.Platform.Windows.Volumes.Binding_Status,
         Trash_API_Name        => To_Unbounded_String ("IFileOperation"),
         Volume_API_Name       => To_Unbounded_String ("GetVolumeInformationW+GetDiskFreeSpaceExW"),
         Trash_Binding_Unit    => To_Unbounded_String ("Files.Platform.Windows.Trash"),
         Volume_Binding_Unit   => To_Unbounded_String ("Files.Platform.Windows.Volumes"),
         Required_Library      => To_Unbounded_String ("shell32;ole32;kernel32"),
         Required_Framework    => Null_Unbounded_String,
         Current_Target        => True,
         Trash_Can_Execute     => Files.Platform.Windows.Trash.Binding_Status =
                                  Files.File_System.Native_API_Binding_Available,
         Volume_Can_Query      => Files.Platform.Windows.Volumes.Can_Query);
   end API_Profile;

   function Native_Locale return String is
      Buffer : aliased Wide_String (1 .. 85) := [others => Wide_Character'Val (0)];
      Length : constant Interfaces.C.int :=
        GetUserDefaultLocaleName (Buffer'Address, Interfaces.C.int (Buffer'Length));
      Result : Unbounded_String;
   begin
      if Length <= 1 then
         return "";
      end if;

      for Index in Buffer'First .. Buffer'Last loop
         exit when Buffer (Index) = Wide_Character'Val (0);
         if Wide_Character'Pos (Buffer (Index)) <= Character'Pos (Character'Last) then
            Append (Result, Character'Val (Wide_Character'Pos (Buffer (Index))));
         end if;
      end loop;

      return To_String (Result);
   exception
      when others =>
         return "";
   end Native_Locale;

   function Evaluate_Trash
     (Request : Files.File_System.Native_Trash_Request)
      return Files.File_System.Native_Trash_Result is
   begin
      return Files.Platform.Windows.Trash.Evaluate (Request);
   end Evaluate_Trash;

   function Move_To_Recycle_Bin
     (Request : Files.File_System.Native_Trash_Request)
      return Files.File_System.Native_Trash_Result is
   begin
      return Files.Platform.Windows.Trash.Move (Request);
   end Move_To_Recycle_Bin;
end Files.Platform.Windows;
