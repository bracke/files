with GNAT.OS_Lib;
with Files.Diagnostics;
with Ada.IO_Exceptions;

with Files.Private_Directories;
with Hostkit.Regular_Files;

package body Files.Exclusive_Streams is
      use type GNAT.OS_Lib.File_Descriptor;

   procedure Create (Stream : in out Output_Stream; Path : String) is
   begin
      if Is_Open (Stream) then
         raise Ada.IO_Exceptions.Status_Error;
      end if;
      Stream.Length := 0;
      Stream.Pending := 0;
      Stream.Descriptor := Hostkit.Regular_Files.Create_New (Path, 8#666#);
      if Stream.Descriptor = GNAT.OS_Lib.Invalid_FD then
         raise Ada.IO_Exceptions.Use_Error;
      end if;
      Files.Private_Directories.Make_File_Private (Stream.Descriptor);
   exception
      when others =>
         Close_Safely (Stream);
         raise;
   end Create;

   procedure Close (Stream : in out Output_Stream) is
      Closed : Boolean;
   begin
      if not Is_Open (Stream) then
         return;
      end if;
      begin
         Flush (Stream);
      exception
         when others =>
            Close_Safely (Stream);
            raise Ada.IO_Exceptions.Use_Error;
      end;
      GNAT.OS_Lib.Close (Stream.Descriptor, Closed);
      Stream.Descriptor := GNAT.OS_Lib.Invalid_FD;
      if not Closed then
         raise Ada.IO_Exceptions.Use_Error;
      end if;
   end Close;

   procedure Close_Safely (Stream : in out Output_Stream) is
   begin
      Stream.Pending := 0;
      if Is_Open (Stream) then
         GNAT.OS_Lib.Close (Stream.Descriptor);
         Stream.Descriptor := GNAT.OS_Lib.Invalid_FD;
      end if;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Exclusive_Streams");
         Stream.Descriptor := GNAT.OS_Lib.Invalid_FD;
   end Close_Safely;

   function Is_Open (Stream : Output_Stream) return Boolean is
     (Stream.Descriptor /= GNAT.OS_Lib.Invalid_FD);

   function Size (Stream : Output_Stream) return Long_Long_Integer is
     (Stream.Length);

   overriding procedure Write
     (Stream : in out Output_Stream;
      Item   : Ada.Streams.Stream_Element_Array)
   is
   begin
      if not Is_Open (Stream)
        or else Long_Long_Integer (Item'Length) >
          Long_Long_Integer'Last - Stream.Length
      then
         raise Ada.IO_Exceptions.Use_Error;
      end if;
      Files.Descriptor_Streams.Output_Stream (Stream).Write (Item);
      Stream.Length := Stream.Length + Long_Long_Integer (Item'Length);
   end Write;
end Files.Exclusive_Streams;
