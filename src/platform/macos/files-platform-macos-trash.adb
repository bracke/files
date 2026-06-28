with Ada.Strings.Unbounded;
with Interfaces.C;
with Interfaces.C.Strings;
with System;

package body Files.Platform.Macos.Trash is
   use Ada.Strings.Unbounded;
   use type Interfaces.C.int;
   use type Files.File_System.Native_API_Binding_Status;

   type FS_Ref is array (1 .. 80) of Interfaces.C.unsigned_char
     with Convention => C;

   procedure Safe_Free
     (Pointer : in out Interfaces.C.Strings.chars_ptr);

   function FSPathMakeRef
     (Path         : Interfaces.C.Strings.chars_ptr;
      Reference    : access FS_Ref;
      Is_Directory : System.Address)
      return Interfaces.C.int
     with Import, Convention => C, External_Name => "FSPathMakeRef";

   function FSMoveObjectToTrashSync
     (Source_Reference : access FS_Ref;
      Target_Reference : System.Address;
      Options          : Interfaces.C.unsigned)
      return Interfaces.C.int
     with Import, Convention => C, External_Name => "FSMoveObjectToTrashSync";

   procedure Safe_Free
     (Pointer : in out Interfaces.C.Strings.chars_ptr) is
   begin
      if Pointer /= Interfaces.C.Strings.Null_Ptr then
         begin
            Interfaces.C.Strings.Free (Pointer);
         exception
            when others =>
               null;
         end;
      end if;
   end Safe_Free;

   function Binding_Status return Files.File_System.Native_API_Binding_Status is
      pragma Unreferenced (FSPathMakeRef, FSMoveObjectToTrashSync);
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
         Binding_Unit    => To_Unbounded_String ("Files.Platform.Macos.Trash"),
         Desktop_Standard => False,
         Would_Delete     => False,
         Uses_Recycle_Bin => False,
         Adapter_Name     => To_Unbounded_String ("macos.trash"),
         Native_Api_Name  => To_Unbounded_String ("FSMoveObjectToTrashSync"),
         Operation_Name   => To_Unbounded_String ("move_to_trash"),
         Requires_User_Consent => False,
         Preserves_Metadata    => True,
         Error_Key        => Null_Unbounded_String);
   end Evaluate;

   function Move
     (Request : Files.File_System.Native_Trash_Request)
      return Files.File_System.Native_Trash_Result
   is
      Path      : Interfaces.C.Strings.chars_ptr :=
        Interfaces.C.Strings.New_String (To_String (Request.Path));
      Reference : aliased FS_Ref;
      Status    : Interfaces.C.int;
      Result    : Files.File_System.Native_Trash_Result := Evaluate (Request);
   begin
      Status := FSPathMakeRef (Path, Reference'Access, System.Null_Address);
      if Status = 0 then
         Status := FSMoveObjectToTrashSync (Reference'Access, System.Null_Address, 0);
      end if;
      Interfaces.C.Strings.Free (Path);
      Result.Attempted := True;
      Result.Completed := Status = 0;
      if not Result.Completed then
         Result.Error_Key := To_Unbounded_String ("error.trash.failed");
      end if;
      return Result;
   exception
      when others =>
         Safe_Free (Path);
         Result.Attempted := True;
         Result.Completed := False;
         Result.Error_Key := To_Unbounded_String ("error.trash.failed");
         return Result;
   end Move;
end Files.Platform.Macos.Trash;
