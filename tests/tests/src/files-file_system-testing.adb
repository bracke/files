with Ada.Strings.Unbounded;

package body Files.File_System.Testing is
   use Ada.Strings.Unbounded;

   function Native_Trash_Request_For
     (Path : String)
      return Native_Trash_Request
   is
      Backend : constant Trash_Backend := Trash_Backend_Of_Current_Environment;
   begin
      return
        (Backend                 => Backend,
         Path                    => To_Unbounded_String (Path),
         Requires_Native_Api     => Backend in Trash_Windows_Recycle_Bin | Trash_Macos_Native,
         Can_Use_Current_Process => Backend not in Trash_Windows_Recycle_Bin | Trash_Macos_Native);
   end Native_Trash_Request_For;

   function Execute_Native_Trash
     (Request : Native_Trash_Request)
      return Native_Trash_Result
   is
      Evaluation : constant Native_Trash_Result := Evaluate_Native_Trash (Request);
      Mutation   : Mutation_Result;
   begin
      if Request.Backend in Trash_Windows_Recycle_Bin | Trash_Macos_Native then
         return Trash_Natively (Request);
      end if;

      if not Evaluation.Supported then
         return Evaluation;
      end if;

      Mutation := Move_To_Trash (To_String (Request.Path));
      return
        (Supported => True,
         Attempted => True,
         Completed => Mutation.Success,
         Error_Key => Mutation.Error_Key);
   end Execute_Native_Trash;

   function Trash_Capabilities_Of_Current_Environment return Trash_Capabilities is
      Backend : constant Trash_Backend := Trash_Backend_Of_Current_Environment;
   begin
      case Backend is
         when Trash_Windows_Recycle_Bin | Trash_Macos_Native =>
            return
              (Backend             => Backend,
               Native_Platform     => True,
               Xdg_Compatible      => False,
               Metadata_Sidecar    => False,
               Collision_Safe_Name => True,
               Permanent_Delete    => False);
         when Trash_Xdg_Data_Home | Trash_Home_Data | Trash_Macos_Home =>
            return
              (Backend             => Backend,
               Native_Platform     => False,
               Xdg_Compatible      => Backend /= Trash_Macos_Home,
               Metadata_Sidecar    => True,
               Collision_Safe_Name => True,
               Permanent_Delete    => False);
         when Trash_Unavailable =>
            return
              (Backend             => Trash_Unavailable,
               Native_Platform     => False,
               Xdg_Compatible      => False,
               Metadata_Sidecar    => False,
               Collision_Safe_Name => False,
               Permanent_Delete    => False);
      end case;
   end Trash_Capabilities_Of_Current_Environment;

   function Root_Discovery_Status return Root_Discovery_Diagnostics is
      Entries : constant Root_Entry_Vectors.Vector := Available_Root_Entries;
      Result  : Root_Discovery_Diagnostics :=
        (Root_Count              => Natural (Entries.Length),
         Ready_Count             => 0,
         Removable_Count         => 0,
         Windows_Drive_Count     => 0,
         Mount_Count             => 0,
         User_Mount_Count        => 0,
         Network_Mount_Count     => 0);
   begin
      for Root of Entries loop
         if Root.Ready = Root_Ready then
            Result.Ready_Count := Result.Ready_Count + 1;
         end if;

         if Root.Removable then
            Result.Removable_Count := Result.Removable_Count + 1;
         end if;

         case Root.Kind is
            when Root_Windows_Drive =>
               Result.Windows_Drive_Count := Result.Windows_Drive_Count + 1;
            when Root_Mount =>
               Result.Mount_Count := Result.Mount_Count + 1;
            when Root_User_Mount =>
               Result.User_Mount_Count := Result.User_Mount_Count + 1;
            when Root_Network_Mount =>
               Result.Network_Mount_Count := Result.Network_Mount_Count + 1;
            when others =>
               null;
         end case;
      end loop;

      return Result;
   end Root_Discovery_Status;

   function Available_Roots return Files.Types.String_Vectors.Vector is
      Entries : constant Root_Entry_Vectors.Vector := Available_Root_Entries;
      Roots   : Files.Types.String_Vectors.Vector;
   begin
      for Root of Entries loop
         Roots.Append (Root.Path);
      end loop;

      return Roots;
   end Available_Roots;

end Files.File_System.Testing;
