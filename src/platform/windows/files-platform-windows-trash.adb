with Ada.Strings.Unbounded;
with Ada.Strings.UTF_Encoding.Wide_Strings;
with Interfaces.C;
with System;

package body Files.Platform.Windows.Trash is
   use Ada.Strings.Unbounded;
   use type Interfaces.C.int;
   use type Interfaces.C.unsigned_short;
   use type Files.File_System.Native_API_Binding_Status;

   type SH_File_Operation_W is record
      Window        : System.Address := System.Null_Address;
      Function_Code : Interfaces.C.unsigned := 0;
      From          : System.Address := System.Null_Address;
      To_Path       : System.Address := System.Null_Address;
      Flags         : Interfaces.C.unsigned_short := 0;
      Any_Aborted   : Interfaces.C.int := 0;
      Name_Mappings : System.Address := System.Null_Address;
      Progress_Title : System.Address := System.Null_Address;
   end record
     with Convention => C;

   function SHFileOperationW
     (Operation : access SH_File_Operation_W)
      return Interfaces.C.int
     with Import, Convention => Stdcall, External_Name => "SHFileOperationW";

   FO_Delete : constant Interfaces.C.unsigned := 3;
   FOF_Silent : constant Interfaces.C.unsigned_short := 16#0004#;
   FOF_No_Confirmation : constant Interfaces.C.unsigned_short := 16#0010#;
   FOF_Allow_Undo : constant Interfaces.C.unsigned_short := 16#0040#;
   FOF_No_Error_UI : constant Interfaces.C.unsigned_short := 16#0400#;

   function Binding_Status return Files.File_System.Native_API_Binding_Status is
   begin
      return Files.File_System.Native_API_Binding_Available;
   end Binding_Status;

   function Evaluate
     (Request : Files.File_System.Native_Trash_Request)
      return Files.File_System.Native_Trash_Result
   is
      pragma Unreferenced (Request);
   begin
      return
        (Supported        => True,
         Attempted        => False,
         Completed        => False,
         Native_Binding_Available => Binding_Status = Files.File_System.Native_API_Binding_Available,
         Native_Binding_Status => Binding_Status,
         Binding_Unit    => To_Unbounded_String ("Files.Platform.Windows.Trash"),
         Desktop_Standard => False,
         Would_Delete     => False,
         Uses_Recycle_Bin => True,
         Adapter_Name     => To_Unbounded_String ("windows.recycle_bin"),
         Native_Api_Name  => To_Unbounded_String ("SHFileOperationW"),
         Operation_Name   => To_Unbounded_String ("move_to_trash"),
         Requires_User_Consent => False,
         Preserves_Metadata    => True,
         Error_Key        => Null_Unbounded_String);
   end Evaluate;

   function Move
     (Request : Files.File_System.Native_Trash_Request)
      return Files.File_System.Native_Trash_Result
   is
      Path_Text : constant String := To_String (Request.Path);
      --  SHFileOperationW expects UTF-16 (16-bit WCHAR). GNAT Wide_String is
      --  16-bit per element, so decode the UTF-8 path to Wide_String and
      --  double-NUL terminate it (pFrom is a double-null-terminated list).
      Wide_Path : aliased Wide_String :=
        Ada.Strings.UTF_Encoding.Wide_Strings.Decode (Path_Text)
          & Wide_Character'Val (0) & Wide_Character'Val (0);
      Operation : aliased SH_File_Operation_W :=
        (Window        => System.Null_Address,
         Function_Code => FO_Delete,
         From          => Wide_Path'Address,
         To_Path       => System.Null_Address,
         Flags         => FOF_Allow_Undo or FOF_No_Confirmation or FOF_No_Error_UI or FOF_Silent,
         Any_Aborted   => 0,
         Name_Mappings => System.Null_Address,
         Progress_Title => System.Null_Address);
      Status : constant Interfaces.C.int := SHFileOperationW (Operation'Access);
      Result : Files.File_System.Native_Trash_Result := Evaluate (Request);
   begin
      Result.Attempted := True;
      Result.Completed := Status = 0 and then Operation.Any_Aborted = 0;
      if not Result.Completed then
         Result.Error_Key := To_Unbounded_String ("error.trash.failed");
      end if;
      return Result;
   end Move;
end Files.Platform.Windows.Trash;
