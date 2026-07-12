with Ada.Strings.Unbounded;
with Interfaces.C;
with System;
with Files.Platform.Macos.Trash;
with Files.Platform.Macos.Volumes;

package body Files.Platform.Macos is
   use Ada.Strings.Unbounded;
   use type System.Address;
   use type Interfaces.C.int;
   use type Files.File_System.Native_API_Binding_Status;

   type CF_Index is new Interfaces.C.long;
   type CF_String_Encoding is new Interfaces.C.unsigned;

   CF_String_Encoding_UTF8 : constant CF_String_Encoding := 16#0800_0100#;

   function CFLocaleCopyCurrent return System.Address
     with Import, Convention => C, External_Name => "CFLocaleCopyCurrent";

   function CFLocaleGetIdentifier
     (Locale : System.Address)
      return System.Address
     with Import, Convention => C, External_Name => "CFLocaleGetIdentifier";

   function CFStringGetCString
     (Text      : System.Address;
      Buffer    : System.Address;
      Buffer_Len : CF_Index;
      Encoding  : CF_String_Encoding)
      return Interfaces.C.int
     with Import, Convention => C, External_Name => "CFStringGetCString";

   procedure CFRelease
     (Object : System.Address)
     with Import, Convention => C, External_Name => "CFRelease";

   function API_Profile return Files.File_System.Native_Platform_API_Profile is
   begin
      return
        (Adapter               => Files.File_System.Native_Adapter_Macos,
         Trash_Binding_Status  => Files.Platform.Macos.Trash.Binding_Status,
         Volume_Binding_Status => Files.Platform.Macos.Volumes.Binding_Status,
         Trash_API_Name        => To_Unbounded_String ("NSFileManager.trashItemAtURL"),
         Volume_API_Name       => To_Unbounded_String ("NSURLResourceValues+statfs"),
         Trash_Binding_Unit    => To_Unbounded_String ("Files.Platform.Macos.Trash"),
         Volume_Binding_Unit   => To_Unbounded_String ("Files.Platform.Macos.Volumes"),
         Required_Library      => Null_Unbounded_String,
         Required_Framework    => To_Unbounded_String ("Foundation"),
         Current_Target        => True,
         Trash_Can_Execute     => Files.Platform.Macos.Trash.Binding_Status =
                                  Files.File_System.Native_API_Binding_Available,
         Volume_Can_Query      => Files.Platform.Macos.Volumes.Can_Query);
   end API_Profile;

   function Native_Locale return String is
      Locale : System.Address := CFLocaleCopyCurrent;
      Buffer : aliased Interfaces.C.char_array (1 .. 128) := [others => Interfaces.C.nul];
      Success : Interfaces.C.int := 0;
   begin
      if Locale = System.Null_Address then
         return "";
      end if;

      declare
         Identifier : constant System.Address := CFLocaleGetIdentifier (Locale);
      begin
         if Identifier /= System.Null_Address then
            Success :=
              CFStringGetCString
                (Identifier,
                 Buffer'Address,
                 CF_Index (Buffer'Length),
                 CF_String_Encoding_UTF8);
         end if;
      end;

      CFRelease (Locale);
      --  Null the handle so the exception handler below cannot release it a
      --  second time if anything after this point (e.g. To_Ada) raises.
      Locale := System.Null_Address;

      if Success = 0 then
         return "";
      end if;

      return Interfaces.C.To_Ada (Buffer);
   exception
      when others =>
         if Locale /= System.Null_Address then
            CFRelease (Locale);
         end if;

         return "";
   end Native_Locale;

   function Evaluate_Trash
     (Request : Files.File_System.Native_Trash_Request)
      return Files.File_System.Native_Trash_Result is
   begin
      return Files.Platform.Macos.Trash.Evaluate (Request);
   end Evaluate_Trash;

   function Move_To_Trash
     (Request : Files.File_System.Native_Trash_Request)
      return Files.File_System.Native_Trash_Result is
   begin
      return Files.Platform.Macos.Trash.Move (Request);
   end Move_To_Trash;
end Files.Platform.Macos;
