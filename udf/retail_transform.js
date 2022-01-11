function process(inJson) {
    
    var obj = JSON.parse(inJson),
    includePubsubMessage = obj.data && obj.attributes,
    data = includePubsubMessage ? obj.data : obj;
      
    data.PAYMENT_METHOD = data.PAYMENT_METHOD.split(':')[0].concat("XXX");
    
    data.ORACLE_SOURCE = data._metadata_schema.concat('.', data._metadata_table);
    
    return JSON.stringify(obj);  
}
