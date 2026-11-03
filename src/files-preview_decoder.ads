with Files.Images;

--  Quick Look's full-size preview, decoded off the UI thread. A camera
--  photo took 50 to 300 ms to read and decode, and moving through a folder
--  with Quick Look open paid that on every key. One worker task decodes the
--  latest request; an older one not yet started is dropped, and a result
--  for a file no longer asked about is never handed out.
package Files.Preview_Decoder is

   --  Ask for Path decoded to fit within Size x Size. Replaces a request
   --  the worker has not started; returns at once.
   --
   --  @param Path Image file.
   --  @param Size Longest side of the decoded preview.
   procedure Request (Path : String; Size : Positive);

   --  The decoded preview of Path, once the worker has finished it. Each
   --  result is handed out once.
   --
   --  @param Path The file the caller previews.
   --  @param Image The decoded preview when Ready (Available False when the
   --    file could not be decoded).
   --  @param Ready True when a result for Path was waiting.
   procedure Take
     (Path  : String;
      Image : out Files.Images.Decoded_Image;
      Ready : out Boolean);

end Files.Preview_Decoder;
