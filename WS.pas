unit WS;

interface

uses
  SysUtils, Classes, Windows, Forms, IdCoder, IdCoder3to4, IdBaseComponent, IdCoderMIME, jpeg, Generics.Collections, ComObj, msxml, msxmldom,  xmldom,  XMLIntf, XMLDoc;

type
  WSConecFM = class(TObject)

private
  { Private declarations }

protected
  { Protected declarations }

public
  { Public declarations }
  function timbrado(layout: string; parametros : TDictionary<string, string>): TDictionary<string, WideString>;
  function cancelado(uuid: string; parametros : TDictionary<string, string>): TDictionary<string, WideString>;
  function base64encode(strLinea: ansiString): ansiString;
  function base64decode(strLinea: ansiString): ansiString;

published
{ Published declarations }

end;

implementation

function WSConecFM.timbrado( layout: string; parametros : TDictionary<string, string> ): TDictionary<string, WideString>;

var F: TFileStream;
    linea, strLinea, layoutB64, soapResponse, cfdi: String;
    XMLHTTPCFDI, xmldoc: OleVariant;
    emisorRFC, userPass, userId, urlTimbrado, generarPDF, generarCBB, generarTXT: string;
    CFDIBase64,PDFBase64, CBBBase64,TXTBase64, UUID: WideString;
    ch: Char;
    resultados : TDictionary<string, WideString>;
    xmlNode, node: IxmlDomNode;
    xml: IXMLDomDocument;

begin
  if FileExists(layout) then
  begin
    F := TFileStream.Create(layout, fmOpenRead );
    while F.Position <> F.Size do
    begin
      F.Read(ch, 1 );
      strLinea := strLinea + ch;
    end;
    F.Free;
    layout := strLinea
  end;
  // Codificar a base 64 el layout
  layoutB64 := base64encode(layout);
   //layout := base64decode(layoutB64);
  parametros.TryGetValue('emisorRFC', emisorRFC);
  parametros.TryGetValue('urlTimbrado', urlTimbrado);
  parametros.TryGetValue('userPass', userPass);
  parametros.TryGetValue('userId', userId);
  parametros.TryGetValue('generarPDF', generarPDF);
  parametros.TryGetValue('generarTXT', generarTXT);
  parametros.TryGetValue('generarCBB', generarCBB);

  resultados := TDictionary<string, WideString>.Create;

  // Objeto encargado de realizar las peticiones http al web service de Facturación Moderna
    XMLHTTPCFDI := CreateOleObject('Microsoft.XMLHTTP');
    XMLHTTPCFDI.Open('POST', urlTimbrado);
    XMLHTTPCFDI.setRequestHeader('Content-Type', 'text/xml; charset=utf-8');
    XMLHTTPCFDI.setRequestHeader('SOAPAction', urlTimbrado);
    XMLHTTPCFDI.send('<?xml version="1.0" encoding="UTF-8"?>'+
                     '<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope" xmlns:ns1="'+urlTimbrado+'" '+
                                   'xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '+
                                   'xmlns:enc="http://www.w3.org/2003/05/soap-encoding">' +
                       '<env:Body>'+
                         '<ns1:requestTimbrarCFDI env:encodingStyle="http://www.w3.org/2003/05/soap-encoding">'+
                           '<param0 xsi:type="enc:Struct">' +
                             '<UserPass xsi:type="xsd:string">' + userPass + '</UserPass>'+
                             '<UserID xsi:type="xsd:string">' + userId + '</UserID>'+
                             '<emisorRFC xsi:type="xsd:string">' + emisorRFC + '</emisorRFC>'+
                             '<text2CFDI xsi:type="xsd:string">' + layoutB64 + '</text2CFDI>'+
                             '<generarTXT xsi:type="xsd:boolean">' + generarTXT + '</generarTXT>'+
                             '<generarPDF xsi:type="xsd:boolean">' + generarPDF + '</generarPDF>'+
                             '<generarCBB xsi:type="xsd:boolean">' + generarCBB + '</generarCBB>'+
                           '</param0>'+
                         '</ns1:requestTimbrarCFDI>'+
                       '</env:Body>'+
                     '</env:Envelope>');
    while (XMLHTTPCFDI.readyState <>  4) do
      Application.ProcessMessages;

    // Respuesta del web service
    soapResponse := XMLHTTPCFDI.responseText;
    // Creamos un objeto capaz de acceder a los nodos de la respuesta en formato XML
    xmldoc := CreateOleObject('Msxml2.DOMDocument.3.0');
    if(xmldoc.loadXML(soapResponse)) then
    begin
      If (xmldoc.getElementsByTagName('env:Fault').length >= 1) Then
      begin
        resultados.Add('code', xmldoc.getElementsByTagName('env:Value').Item(0).Text);
        resultados.Add('message', xmldoc.getElementsByTagName('env:Text').Item(0).Text);
        Result := resultados;
      end
      else
      begin
        // Obtenemos el nodo xml contenedor del CFDI
        CFDIBase64 := xmldoc.getElementsByTagName('xml').Item(0).Text;
        resultados.Add('xmlb64', CFDIBase64);

        // Obtenemos el UUID
        cfdi := base64decode(CFDIBase64);
        xml := CoDOMDocument.create;
        xml.loadXML(cfdi);
        xmlNode := xml.documentElement;
        node:=xml.documentElement.getElementsByTagName('tfd:TimbreFiscalDigital').item[0];
        UUID := node.attributes.getNamedItem('UUID').Text;
        resultados.Add('uuid', UUID);

        // Obtenemos la representación impresa del CFDI en formato PDF
        if generarPDF = 'true' then
        begin
          PDFBase64 := xmldoc.getElementsByTagName('pdf').Item(0).Text;
          resultados.Add('pdfb64', PDFBase64);
        end;
        // Obtenemos la representación impresa del CFDI en formato PDF
        if generarTXT = 'true' then
        begin
          TXTBase64 := xmldoc.getElementsByTagName('txt').Item(0).Text;
          resultados.Add('txtb64', TXTBase64);
        end;
        // Obtenemos la representación impresa del CFDI en formato PDF
        if generarCBB = 'true' then
        begin
          CBBBase64 := xmldoc.getElementsByTagName('png').Item(0).Text;
          resultados.Add('cbbb64', CBBBase64);
        end;
        Result := resultados;
      end;
    end
    else
    begin
      resultados.Add('code', 'E-001');
      resultados.Add('message', 'No se logro crear el XML de soapResponse');
      Result := resultados;
    end;
end; // Fin de timbrado


function WSConecFM.cancelado(uuid: string; parametros: TDictionary<System.string,System.string>) : TDictionary<string, WideString>;
var
  soapResponse: String;
  XMLHTTPCFDI, xmldoc: OleVariant;
  emisorRFC, userPass, userId, urlCancelado: string;
  resultados : TDictionary<string, WideString>;
  xmlNode, node: IxmlDomNode;
  xml: IXMLDomDocument;

begin
  parametros.TryGetValue('emisorRFC', emisorRFC);
  parametros.TryGetValue('urlCancelado', urlCancelado);
  parametros.TryGetValue('userPass', userPass);
  parametros.TryGetValue('userId', userId);

  resultados := TDictionary<string, WideString>.Create;

  XMLHTTPCFDI := CreateOleObject('Microsoft.XMLHTTP');
  XMLHTTPCFDI.Open('POST', urlCancelado);
  XMLHTTPCFDI.setRequestHeader('Content-Type', 'text/xml; charset=utf-8');
  XMLHTTPCFDI.setRequestHeader('SOAPAction', urlCancelado);
  XMLHTTPCFDI.send('<?xml version="1.0" encoding="UTF-8"?>' +
                   '<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" ' +
                                      'xmlns:ns1="https://t2demo.facturacionmoderna.com/timbrado/soap" '+
                                      'xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" ' +
                                      'xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">' +
                    '<SOAP-ENV:Body>'+
                      '<ns1:requestCancelarCFDI>' +
                        '<request xsi:type="SOAP-ENC:Struct">' +
                          '<uuid xsi:type="xsd:string">' + uuid + '</uuid>' +
                          '<emisorRFC xsi:type="xsd:string">' + emisorRFC + '</emisorRFC>' +
                          '<UserID xsi:type="xsd:string">' + userId + '</UserID>' +
                          '<UserPass xsi:type="xsd:string">' + userPass + '</UserPass>' +
                        '</request>' +
                      '</ns1:requestCancelarCFDI>' +
                    '</SOAP-ENV:Body>' +
                   '</SOAP-ENV:Envelope>');
  while (XMLHTTPCFDI.readyState <>  4) do
    Application.ProcessMessages;

  // Respuesta del web service
  soapResponse := XMLHTTPCFDI.responseText;
  // Creamos un objeto capaz de acceder a los nodos de la respuesta en formato XML
  xmldoc := CreateOleObject('Msxml2.DOMDocument.3.0');
  if(xmldoc.loadXML(soapResponse)) then
  begin
    If (xmldoc.getElementsByTagName('SOAP-ENV:Fault').length >= 1) Then
    begin
      resultados.Add('code', xmldoc.getElementsByTagName('faultcode').Item(0).Text);
      resultados.Add('message', xmldoc.getElementsByTagName('faultstring').Item(0).Text);
      Result := resultados;
    end
    else
    begin
      resultados.Add('message', xmldoc.getElementsByTagName('Message').Item(0).Text);
      Result := resultados;
    end;
  end
  else
  begin
    resultados.Add('code', '0000');
    resultados.Add('message', 'No se logro cargar el soapResponse');
    Result := resultados;
  end;
end; // Fin de Cancelado

function WSConecFM.base64encode(strLinea: AnsiString): ansiString;
  var Encoder : TIdEncoderMime;
  begin
    Encoder := TIdEncoderMime.Create(nil);
    try
      Result := Encoder.EncodeString(strLinea);
    finally
      FreeAndNil(Encoder);
  end;
end;

function WSConecFM.base64decode(strLinea: AnsiString): ansiString;
  var Decoder : TIdDecoderMime;
  begin
    Decoder := TIdDecoderMime.Create(nil);
    try
      Result := Decoder.DecodeString(strLinea);
    finally
      FreeAndNil(Decoder)
  end
end;

// Fin de Implementation
end.
