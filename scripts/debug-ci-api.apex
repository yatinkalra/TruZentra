// Probe for churn_data CI table
List<String> ciProbes = new List<String>{
    'churn_data__cio', 'churn_data', 'Churn_Data__cio', 'Churn_Data',
    'Zentra_Customer_Churn_Risk__cio', 'Customer_Churn_Risk__cio',
    'churn_risk__cio', 'Churn_Risk__cio'
};
for (String ci : ciProbes) {
    try {
        ConnectApi.CdpQueryInput qi = new ConnectApi.CdpQueryInput();
        qi.sql = 'SELECT * FROM ' + ci + ' LIMIT 2';
        ConnectApi.CdpQueryOutputV2 out = ConnectApi.CdpQuery.queryAnsiSqlV2(qi);
        String cols = '';
        for (String k : out.metadata.keySet()) { cols += k + ', '; }
        System.debug('FOUND CI: ' + ci + ' → ' + cols);
        System.debug('CI DATA: ' + JSON.serialize(out.data).left(2000));
    } catch (Exception e) {
        System.debug('MISS CI: ' + ci);
    }
}
