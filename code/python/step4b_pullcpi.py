
import requests
import json
import pandas as pd


#Set Proxy
API_key = "Insert API Key Here"

filepath = r'derived_data/CEX/seriesid.csv'
outputpath= r'derived_data/CPI/seriesprices_na_'

minyear = 1961
maxyear = 2022


seriesid = pd.read_csv(filepath)
seriesid = seriesid[0:]
j = 0
for code in seriesid['CPICode']:
    print(j)
    df_prices = pd.DataFrame()
    for year in range(minyear,maxyear+1,20): 
        headers = {'Content-type': 'application/json'}
        data = json.dumps({"seriesid": [code],"startyear":str(year), "endyear":str(year+19),"registrationkey":API_key})
        p = requests.post('https://api.bls.gov/publicAPI/v2/timeseries/data/', data=data, headers=headers)
        df = pd.DataFrame()
        json_data = json.loads(p.text)
        i = 0
        for series in json_data['Results']['series']:    
            dftmp = pd.DataFrame(series['data'])
            dftmp['series_id'] = i
            df = pd.concat([df, dftmp], 0)
            i += 1
        if 'value' not in df:
            print('Missing Data' + '   ' + str(year) + '  ' + code)
        else:
            df_prices = df_prices.append(df[['year','period','value']],sort=True)
            df_prices['CPICode'] = code
		
    save = outputpath + str(j) + ".csv"
    df_prices.to_csv(save)
    j += 1

